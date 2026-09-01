#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'

cd "$repo_dir"
nix flake update
nix flake check --no-build

echo
git --no-pager diff --stat -- flake.lock
echo
echo "Inputs updated and validated. Review with: git diff -- flake.lock"
echo "Then test with: ./apply.sh test"
