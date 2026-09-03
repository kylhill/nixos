{
  config,
  inputs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ./disko.nix
    ./hardware.nix
    inputs.nixos-hardware.nixosModules.system76
    ../../modules/nixos/admin-tools.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop-theme.nix
    ../../modules/nixos/graphical-boot.nix
    ../../modules/nixos/gnome-workstation.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/networkmanager-wireguard.nix
    ../../modules/nixos/networkmanager-wifi.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/shared-ssh-identity.nix
    ../../modules/nixos/user-kyleh.nix
    ../../modules/nixos/zfs-root.nix
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi = {
        canTouchEfiVariables = false;
      };
    };

    kernelParams = [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=zsmalloc"
      "zswap.max_pool_percent=20"
      "zswap.shrinker_enabled=1"
    ];

    zfs = {
      # This pool belongs exclusively to pang14. Forced import is an explicit
      # policy choice so the host recovers automatically after an unclean
      # shutdown or an installer import under a different host ID.
      forceImportRoot = true;
      forceImportAll = false;
    };
  };

  services.zfs = {
    autoSnapshot = {
      enable = true;
      frequent = 0;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 3;
    };

    autoScrub = {
      enable = true;
      interval = "monthly";
    };

    trim = {
      enable = true;
      interval = "weekly";
    };
  };

  sops.defaultSopsFile = ../../secrets/pang14.yaml;

  users.users.${config.infrastructure.user.name}.extraGroups = [ "dialout" ];

  system.stateVersion = "26.05";
}
