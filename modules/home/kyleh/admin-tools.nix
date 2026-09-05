{ pkgs, ... }:
{
  home.packages = [
    pkgs.curl
    pkgs.dnsutils
    pkgs.iotop
    pkgs.ncdu
    pkgs.rsync
    pkgs.wget
  ];
}
