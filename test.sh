#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'

cd "$repo_dir"

run_stage() {
    local description=$1
    shift

    printf '\n==> %s\n' "$description"
    "$@"
}

run_stage "Evaluating all flake outputs without building them" \
    nix flake check --no-build

system=$(nix eval --impure --raw --expr builtins.currentSystem)

for check in formatting statix deadnix shellcheck; do
    run_stage "Running the $check check" \
        nix build --no-link ".#checks.${system}.$check"
done

printf '\nAll development checks passed. No system build or activation was run.\n'
