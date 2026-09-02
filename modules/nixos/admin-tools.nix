{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.curl
    pkgs.git
    pkgs.lsof
    pkgs.rsync
    pkgs.wget
  ];
}
