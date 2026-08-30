#!/usr/bin/env bash
set -euo pipefail

# Home Manager is integrated into the NixOS configuration.
cd "$(dirname "$0")"
exec nh os switch .#pang14
