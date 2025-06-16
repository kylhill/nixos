#!/bin/sh
set -e

cd ~/nixos
sudo nixos-rebuild switch -I nixos-config=./system/configuration.nix
