#!/usr/bin/env bash
# Host-selection tests with fake tools: never build or activate real outputs.
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/repo" "$fixture_dir/tools/bin"
cp "$repo_dir/apply.sh" "$fixture_dir/repo/"
for tool in home-manager hostname nixos-rebuild sudo; do
    cp "$repo_dir/tests/fixtures/apply-tool" "$fixture_dir/tools/bin/$tool"
    chmod +x "$fixture_dir/tools/bin/$tool"
done
export PATH="$fixture_dir/tools/bin:/usr/bin:/bin"
export FIXTURE_LOG="$fixture_dir/calls"

run_case() {
    local host=$1 action=$2 expected=$3 status=0
    export FIXTURE_HOST=$host
    : > "$FIXTURE_LOG"
    bash "$fixture_dir/repo/apply.sh" "$action" > "$fixture_dir/output" 2>&1 || status=$?
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

run_case pang14 test 0
[[ $calls == *"nixos-rebuild test --flake $fixture_dir/repo#pang14" ]]
[[ $calls != *home-manager* ]]

run_case oci boot 2
[[ -z $calls ]]
grep -q 'boot is only available for the pang14 NixOS configuration' "$fixture_dir/output"

echo 'Apply script fixtures passed.'
