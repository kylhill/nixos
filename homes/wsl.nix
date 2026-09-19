{ pkgs, ... }:
{
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/direnv.nix
    ../modules/home/kyleh/ubuntu-headless.nix
  ];

  home.packages = [
    pkgs.age
    pkgs.sops
  ];
}
