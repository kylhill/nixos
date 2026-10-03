#!/usr/bin/env bash
# Isolate PowerShell startup state as well as the mocked script fixtures.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if ! command -v pwsh >/dev/null 2>&1; then
    echo 'Cannot run pwsh: expected on PATH from the default development shell.' >&2
    exit 1
fi
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
export TMPDIR="$fixture_dir"
export XDG_CACHE_HOME="$fixture_dir/cache"
export XDG_CONFIG_HOME="$fixture_dir/config"
export XDG_DATA_HOME="$fixture_dir/data"
pwsh -NoLogo -NoProfile -File "$repo_dir/tests/test-windows.ps1"
