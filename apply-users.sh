#!/bin/sh
set -e

cd ~/nixos
sudo home-manager switch -f ./users/kyleh/home.nix
