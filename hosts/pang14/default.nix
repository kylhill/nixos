{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/networkmanager-vpn.nix
    ../../modules/nixos/networkmanager-wifi.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/workstation-zfs.nix
    ../../modules/nixos/system76.nix
    ../../modules/nixos/user-kyleh.nix
    ../../modules/nixos/workstation.nix
  ];

  networking = {
    inherit (config.infrastructure.host) hostId;
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi = {
      canTouchEfiVariables = false;
    };
  };

  sops.defaultSopsFile = ../../secrets/pang14.yaml;

  system.stateVersion = "26.05";

  fonts.packages = [ pkgs.nerd-fonts.caskaydia-cove ];
}
