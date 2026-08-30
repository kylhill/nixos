#!/usr/bin/env bash
set -euo pipefail

# System and Home Manager inputs share one lock file.
cd "$(dirname "$0")"
exec nix flake update
