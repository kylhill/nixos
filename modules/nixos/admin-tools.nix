{ pkgs, ... }:
{
  programs.nh.enable = true;

  environment.systemPackages = [
    pkgs.ethtool
    pkgs.gparted
    pkgs.lm_sensors
    pkgs.lsof
    pkgs.nvme-cli
    pkgs.pciutils
    pkgs.powertop
    pkgs.smartmontools
    pkgs.tcpdump
    pkgs.usbutils
  ];
}
