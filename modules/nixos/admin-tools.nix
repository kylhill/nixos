{ pkgs, ... }:
{
  programs.nh.enable = true;

  environment.systemPackages = [
    pkgs.curl
    pkgs.dnsutils
    pkgs.ethtool
    pkgs.gparted
    pkgs.lm_sensors
    pkgs.lsof
    pkgs.ncdu
    pkgs.nvme-cli
    pkgs.pciutils
    pkgs.powertop
    pkgs.rsync
    pkgs.smartmontools
    pkgs.tcpdump
    pkgs.usbutils
    pkgs.wget
  ];
}
