{
  host,
  hostName,
  nixosModules,
  pkgs,
  system76HardwareModule,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    system76HardwareModule
    nixosModules.base
    nixosModules.laptop
    nixosModules.networkmanager-vpn
    nixosModules.networkmanager-wifi
    nixosModules.secrets
    nixosModules.workstation-zfs
    nixosModules.system76
    nixosModules.user-kyleh
    nixosModules.workstation
  ];

  networking = {
    inherit hostName;
    inherit (host) hostId;
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
