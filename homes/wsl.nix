{ pkgs, ... }:
{
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/direnv.nix
    ../modules/home/kyleh/ubuntu.nix
  ];

  targets.genericLinux = {
    enable = true;
  };

  home.packages = [
    pkgs.age
    pkgs.sops
  ];

  programs.nixvim.waylandSupport = false;
}
