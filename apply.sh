#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
action="${1:-switch}"
host_name=$(hostname --short)

if [[ -n ${WSL_DISTRO_NAME:-} ]] || grep -qi microsoft /proc/sys/kernel/osrelease; then
    home_name=wsl
else
    home_name=$host_name
fi

case "$action" in
    build|boot|switch|test) ;;
    *)
        echo "usage: $0 [build|boot|switch|test]" >&2
        exit 2
        ;;
esac

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'

cd "$repo_dir"

if [[ $host_name == pang14 ]]; then
    # Passing NIX_CONFIG explicitly makes the script work during bootstrap as
    # well as after this configuration has enabled flakes globally.
    exec sudo env NIX_CONFIG="$NIX_CONFIG" \
        nixos-rebuild "$action" --flake "$repo_dir#pang14"
fi

case "$action" in
    build|switch)
        exec home-manager "$action" --flake "path:$repo_dir#$home_name"
        ;;
    boot|test)
        echo "$action is only available for the pang14 NixOS configuration" >&2
        exit 2
        ;;
esac
