#!/usr/bin/env bash
# Test orchestration with fake Nix/tools: never evaluate or build real outputs.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/repo/scripts" "$fixture_dir/repo/tests/fixtures" "$fixture_dir/tools/bin"
cp "$repo_dir/test.sh" "$repo_dir/apply.sh" "$repo_dir/update.sh" "$repo_dir/flake.lock" "$fixture_dir/repo/"
cp "$repo_dir/scripts/"{nix-sandbox,install-host-key,install-preflight} "$fixture_dir/repo/scripts/"
cp "$repo_dir/tests/test-runner.sh" "$fixture_dir/repo/tests/"
cp "$repo_dir/tests/fixtures/validation-tool" "$fixture_dir/repo/tests/fixtures/"
for tool in nix nixfmt statix deadnix shellcheck; do
    cp "$repo_dir/tests/fixtures/validation-tool" "$fixture_dir/tools/bin/$tool"
    chmod +x "$fixture_dir/tools/bin/$tool"
done
git -C "$fixture_dir/repo" init -q
export PATH="$fixture_dir/tools/bin:$PATH"
export FIXTURE_TOOLS="$fixture_dir/tools" FIXTURE_LOG="$fixture_dir/calls"
# Isolate the daemonless wrapper's cache directories too.
export TMPDIR="$fixture_dir"
export NIX_SANDBOX_ROOT="$fixture_dir/nix"
unset NIX_SANDBOX_BACKEND
run_case() {
    local expected=$1 status=0
    shift
    : > "$FIXTURE_LOG"
    bash "$fixture_dir/repo/test.sh" "$@" > "$fixture_dir/output" 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        cat "$fixture_dir/output"
        echo "Expected exit $expected, got $status: $*" >&2
        exit 1
    fi
    calls=$(< "$FIXTURE_LOG")
}
require_call() { [[ $calls == *"$1"* ]] || { echo "Missing call: $1" >&2; exit 1; }; }
reject_call() { [[ $calls != *"$1"* ]] || { echo "Unexpected call: $1" >&2; exit 1; }; }
reject_nix() { if grep -q '^nix ' "$FIXTURE_LOG"; then echo 'Unexpected Nix invocation' >&2; exit 1; fi; }

run_case 0 --sandbox --offline --lint
reject_call 'flake check'
reject_call 'homeConfigurations'
reject_call 'devShells'
require_call 'nixfmt'
reject_nix
[[ ! -e $NIX_SANDBOX_ROOT ]]

# Missing PATH tools resolve together; subsequent lint runs use only cached
# pinned paths, even with the daemon unavailable.
mkdir -p "$fixture_dir/pinned/bin"
for tool in nixfmt statix deadnix shellcheck; do
    mv "$fixture_dir/tools/bin/$tool" "$fixture_dir/pinned/bin/$tool"
done
export FIXTURE_TOOLS="$fixture_dir/pinned"
run_case 0 --sandbox --offline --lint
require_call '--store daemon --offline eval'
[[ $(grep -c concatStringsSep "$FIXTURE_LOG") == 1 ]]
[[ ! -e $NIX_SANDBOX_ROOT/store ]]
export FAIL_DAEMON=1
run_case 0 --sandbox --lint
reject_nix
[[ ! -e $NIX_SANDBOX_ROOT/store ]]
unset FAIL_DAEMON

run_case 0 --sandbox --home gateway --home oci --dev aarch64-linux
require_call 'homeConfigurations.gateway.activationPackage.drvPath'
require_call 'homeConfigurations.oci.activationPackage.drvPath'
require_call 'devShells.aarch64-linux'
require_call '--store daemon'
reject_call 'flake check'
reject_call 'homeConfigurations.syntax'
reject_call 'nix build'

run_case 0 --sandbox --full
require_call 'flake check path:. --no-build --all-systems'
require_call 'path:.#homeConfigurations --no-update-lock-file'
run_case 0 --sandbox
require_call 'flake check'

run_case 0 --path --lint
require_call 'build --no-link --no-update-lock-file path:.#checks.x86_64-linux.formatting'
reject_call 'flake check'

export FAIL_TOOL=statix
run_case 1 --sandbox --full
require_call 'shellcheck'
reject_call 'flake check'
unset FAIL_TOOL

# A changed lock invalidates the tool cache. Partial tool availability still
# permits independent linters to run when resolution fails.
printf '\n' >> "$fixture_dir/repo/flake.lock"
cp "$fixture_dir/pinned/bin/shellcheck" "$fixture_dir/tools/bin/shellcheck"
export FAIL_RESOLVE=1
run_case 1 --sandbox --lint
require_call 'shellcheck'
unset FAIL_RESOLVE
run_case 0 --sandbox --lint
require_call 'concatStringsSep'

export FAIL_DAEMON=1
run_case 1 --sandbox --offline --home gateway
require_call '--store daemon --offline eval'
reject_call 'store info'
reject_call "--store $NIX_SANDBOX_ROOT/store"
[[ ! -e $NIX_SANDBOX_ROOT/store ]]
unset FAIL_DAEMON
export NIX_SANDBOX_BACKEND=daemon
run_case 0 --sandbox --home gateway
reject_call 'store info'
require_call '--store daemon eval'
export NIX_SANDBOX_BACKEND=local
run_case 0 --sandbox --home gateway
reject_call 'store info'
require_call "--store $NIX_SANDBOX_ROOT/store eval"
[[ -d $NIX_SANDBOX_ROOT/store ]]
export NIX_SANDBOX_BACKEND=auto
run_case 1 --sandbox --home gateway
reject_call 'homeConfigurations'
export NIX_SANDBOX_BACKEND=invalid
run_case 1 --sandbox --home gateway
reject_call 'homeConfigurations'
unset NIX_SANDBOX_BACKEND

run_case 1 --sandbox --offline --home missing --home gateway
require_call 'homeConfigurations.gateway'
[[ $(< "$fixture_dir/output") == *'rerun the same scope without --offline'* ]]
for scope in --home --dev; do
    run_case 2 "$scope"
    run_case 2 "$scope" 'bad.name'
    run_case 2 --full "$scope" syntax
    run_case 2 "$scope" syntax --lint
done
run_case 2 --unknown
run_case 2 --lint --full
run_case 0 --help
[[ -z $calls ]]
echo 'Validation runner fixtures passed.'
