#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
flake_ref="."

case "${1:-}" in
    "") ;;
    --path) flake_ref="path:." ;;
    *)
        echo "usage: $0 [--path]" >&2
        exit 2
        ;;
esac

sandbox_nix_root="${TMPDIR:-/tmp}/nixos-codex-nix-${UID}"
sandbox_store_root="$sandbox_nix_root/store"
sandbox_cache_root="$sandbox_nix_root/cache"

install -d -m 0700 "$sandbox_store_root" "$sandbox_cache_root"

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
export XDG_CACHE_HOME="$sandbox_cache_root"

cd "$repo_dir"

echo "Evaluating $flake_ref with the daemonless store at $sandbox_store_root"
exec nix flake check "$flake_ref" \
    --store "$sandbox_store_root" \
    --no-build
