#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
action="${1:-switch}"

case "$action" in
    build|boot|switch|test) ;;
    *)
        echo "usage: $0 [build|boot|switch|test]" >&2
        exit 2
        ;;
esac

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'

cd "$repo_dir"

# Passing NIX_CONFIG explicitly makes the script work during bootstrap as well
# as after this configuration has enabled flakes globally.
exec sudo env NIX_CONFIG="$NIX_CONFIG" \
    nixos-rebuild "$action" --flake "$repo_dir#pang14"
