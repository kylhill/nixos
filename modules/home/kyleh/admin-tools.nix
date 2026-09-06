{ pkgs, ... }:
{
  home.packages = [
    pkgs.curl
    pkgs.dnsutils
    pkgs.ncdu
    pkgs.rsync
    pkgs.wget
  ];
}
