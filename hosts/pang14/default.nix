{
  config,
  inputs,
  pkgs,
  ...
}:
let
  secretsFile = "${toString ../..}/secrets/pang14.yaml";
  secretsAvailable = builtins.pathExists secretsFile;
in
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
    enable = secretsAvailable;
    file = secretsFile;
  };

  fonts.packages = [ pkgs.cascadia-code ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit inputs; };
    users.kyleh = import ../../modules/home/kyleh;
  };

  # Keep evaluation possible while secrets are bootstrapped. If the encrypted
  # file is absent, set a local password from the installer before rebooting.
  users.users.kyleh = {
    createHome = true;
    home = "/home/kyleh";
  };
}
