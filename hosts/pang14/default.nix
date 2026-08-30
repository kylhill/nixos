{
  inputs,
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
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/storage-zfs.nix
    ../../modules/nixos/wireguard.nix
  ];

  networking = {
    hostName = "pang14";
    hostId = "ab5f3534";
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    efi.canTouchEfiVariables = true;
  };

  tacomafia.secrets = {
    enable = true;
    # Keep this as a Nix path, rather than converting the repository root to a
    # string, so the encrypted file is an explicit flake/store dependency.
    file = ../../secrets/pang14.yaml;
  };

  fonts.packages = [ pkgs.nerd-fonts.caskaydia-cove ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
    users.kyleh = import ../../modules/home/kyleh;
  };

  users.users.kyleh = {
    createHome = true;
    home = "/home/kyleh";
  };
}
