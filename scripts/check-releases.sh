#!/usr/bin/env bash
# Check source release references without evaluating or building Nix outputs.
set -euo pipefail
source_file=${1:-flake.nix}
releases=()
for prefix in github:NixOS/nixpkgs/nixos- github:nix-community/home-manager/release- github:nix-community/nixvim/nixos-; do
    matches=()
    pattern="$prefix"'([0-9]{2}\.[0-9]{2})"'
    while IFS= read -r line; do
        if [[ $line =~ $pattern ]]; then matches+=("${BASH_REMATCH[1]}"); fi
    done < "$source_file"
    if [[ ${#matches[@]} != 1 ]]; then
        echo "Expected one release reference for $prefix" >&2
        exit 1
    fi
    releases+=("${matches[0]}")
done
for release in "${releases[@]}"; do
    if [[ $release != "${releases[0]}" ]]; then
        echo 'Nixpkgs, Home Manager and Nixvim releases must match' >&2
        exit 1
    fi
done
