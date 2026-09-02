{ pkgs, ... }:
{
  home.packages = [
    pkgs.iotop
    pkgs.nvme-cli
    pkgs.powertop
  ];
}
