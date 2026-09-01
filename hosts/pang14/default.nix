{
  host,
  hostName,
  inputs,
  inventory,
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop-gnome.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/networkmanager-vpn.nix
    ../../modules/nixos/networkmanager-wifi.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/storage-zfs.nix
    ../../modules/nixos/system76.nix
  ];

  networking = {
    inherit hostName;
    hostId = host.id;
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

  fonts.packages = [ pkgs.nerd-fonts.caskaydia-cove ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit
        host
        hostName
        inputs
        inventory
        ;
    };
    sharedModules = [ inputs.nix-index-database.homeModules.default ];
    users.${inventory.user.name} = import ../../modules/home/kyleh;
  };
}
