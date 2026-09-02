{
  nixos-hardware,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    nixos-hardware.nixosModules.system76
    ../../modules/nixos/base.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/networkmanager-vpn.nix
    ../../modules/nixos/networkmanager-wifi.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/shared-ssh-identity.nix
    ../../modules/nixos/workstation-zfs.nix
    ../../modules/nixos/system76-desktop-policy.nix
    ../../modules/nixos/user-kyleh.nix
    ../../modules/nixos/workstation.nix
  ];

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
