{ pkgs, ... }:
{
  programs.nh.enable = true;

  environment.systemPackages = [
    pkgs.curl
    pkgs.ethtool
    pkgs.git
    pkgs.gparted
    pkgs.iotop
    pkgs.lm_sensors
    pkgs.lsof
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
