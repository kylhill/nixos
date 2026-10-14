#!/usr/bin/env bash
# The Windows suite owns launcher behavior as well as PowerShell fixtures.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/bin"
for tool in bash dirname mktemp rm; do
    ln -s "$(command -v "$tool")" "$fixture_dir/bin/$tool"
done
export WRAPPER_LOG="$fixture_dir/launcher-directory"
export EXPECTED_WRAPPER_ROOT="$fixture_dir"
export EXPECTED_WINDOWS_SCRIPT="$repo_dir/tests/test-windows.ps1"
run_wrapper() {
    local expected=$1 status=0
    : > "$WRAPPER_LOG"
    PATH="$fixture_dir/bin" TMPDIR="$fixture_dir" \
        XDG_CACHE_HOME=sentinel-cache XDG_CONFIG_HOME=sentinel-config XDG_DATA_HOME=sentinel-data \
        bash "$repo_dir/tests/run-windows.sh" > "$fixture_dir/output" 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        cat "$fixture_dir/output"
        echo "Expected Windows launcher exit $expected, got $status" >&2
        exit 1
    fi
    if [[ -s $WRAPPER_LOG ]]; then
        [[ ! -e $(< "$WRAPPER_LOG") ]] || { echo 'Windows launcher scratch was not cleaned.' >&2; exit 1; }
    fi
}
# A missing interpreter fails clearly without requiring a real PowerShell run.
run_wrapper 1
[[ $(< "$fixture_dir/output") == *'Cannot run pwsh'* ]]
printf '#!%s\n' "$(command -v bash)" > "$fixture_dir/bin/pwsh"
cat >> "$fixture_dir/bin/pwsh" <<'EOF'
set -euo pipefail
[[ $# == 4 && $1 == -NoLogo && $2 == -NoProfile && $3 == -File ]]
[[ $4 == "$EXPECTED_WINDOWS_SCRIPT" ]]
[[ $TMPDIR == "$EXPECTED_WRAPPER_ROOT"/* ]]
[[ $XDG_CACHE_HOME == "$TMPDIR/cache" && $XDG_CONFIG_HOME == "$TMPDIR/config" && $XDG_DATA_HOME == "$TMPDIR/data" ]]
printf '%s' "$TMPDIR" > "$WRAPPER_LOG"
exit "${WRAPPER_EXIT:-0}"
EOF
chmod +x "$fixture_dir/bin/pwsh"
WRAPPER_EXIT=0 run_wrapper 0
WRAPPER_EXIT=17 run_wrapper 17
# The same launcher now executes the real parser/mocked-orchestration suite.
bash "$repo_dir/tests/run-windows.sh"
