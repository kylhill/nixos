#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'

cd "$repo_dir"
# Update the working tree without asking Nix's Git fetcher to stage the lock file.
nix flake update --flake path:. "$@"

echo
git --no-pager diff --stat -- flake.lock
echo
echo "Inputs updated. Review with: git diff -- flake.lock"
echo "Then validate with: ./test.sh --full"
