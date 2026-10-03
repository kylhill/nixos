#!/usr/bin/env bash
# Host-selection tests with fake tools: never build or activate real outputs.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/repo" "$fixture_dir/tools/bin"
export FIXTURE_GREP
FIXTURE_GREP=$(command -v grep)
for tool in bash cat dirname rm; do
    ln -s "$(command -v "$tool")" "$fixture_dir/tools/bin/$tool"
done
cp "$repo_dir/apply.sh" "$fixture_dir/repo/"
for tool in home-manager hostname nixos-rebuild sudo grep; do
    {
        printf '#!%s\n' "$(command -v bash)"
        tail -n +2 "$repo_dir/tests/fixtures/apply-tool"
    } > "$fixture_dir/tools/bin/$tool"
    chmod +x "$fixture_dir/tools/bin/$tool"
done
export PATH="$fixture_dir/tools/bin"
export FIXTURE_LOG="$fixture_dir/calls"

run_case() {
    local host=$1 action=$2 expected=$3 wsl_name=${4:-} kernel_wsl=${5:-false} status=0
    export FIXTURE_HOST=$host
    export WSL_DISTRO_NAME=$wsl_name
    export FIXTURE_KERNEL_WSL=$kernel_wsl
    : > "$FIXTURE_LOG"
    action_args=()
    if [[ $action != DEFAULT ]]; then action_args+=("$action"); fi
    bash "$fixture_dir/repo/apply.sh" "${action_args[@]}" > "$fixture_dir/output" 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        cat "$fixture_dir/output"
        echo "Expected exit $expected, got $status: $host $action" >&2
        exit 1
    fi
    calls=$(< "$FIXTURE_LOG")
}

run_case syntax switch 0
[[ $calls == "home-manager switch --flake path:$fixture_dir/repo#syntax" ]]

run_case gateway build 0
[[ $calls == "home-manager build --flake path:$fixture_dir/repo#gateway" ]]

run_case windows-host switch 0 Ubuntu
[[ $calls == "home-manager switch --flake path:$fixture_dir/repo#wsl" ]]

run_case pang14 switch 0 Ubuntu
[[ $calls == "home-manager switch --flake path:$fixture_dir/repo#wsl" ]]

run_case pang14 build 0 Ubuntu
[[ $calls == "home-manager build --flake path:$fixture_dir/repo#wsl" ]]

run_case pang14 test 2 Ubuntu
[[ -z $calls ]]
grep -q 'test is only available for the pang14 NixOS configuration' "$fixture_dir/output"

run_case pang14 test 0
[[ $calls == *"nixos-rebuild test --flake $fixture_dir/repo#pang14" ]]
[[ $calls != *home-manager* ]]

run_case oci boot 2
[[ -z $calls ]]
grep -q 'boot is only available for the pang14 NixOS configuration' "$fixture_dir/output"

run_case syntax DEFAULT 0
[[ $calls == "home-manager switch --flake path:$fixture_dir/repo#syntax" ]]
run_case pang14 switch 0 '' true
[[ $calls == "home-manager switch --flake path:$fixture_dir/repo#wsl" ]]
run_case pang14 boot 2 '' true
[[ -z $calls ]]
run_case syntax invalid 2
[[ -z $calls ]]
export FAIL_APPLY_TOOL=home-manager
run_case syntax switch 17
[[ $calls == home-manager* ]]
export FAIL_APPLY_TOOL=sudo
run_case pang14 switch 17
[[ $calls == sudo* ]]
unset FAIL_APPLY_TOOL
echo 'Apply script fixtures passed.'
