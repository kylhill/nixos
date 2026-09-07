{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ./disko.nix
    ./hardware.nix
    ./zfs-backup.nix
    inputs.nixos-hardware.nixosModules.system76
    ../../modules/nixos/admin-tools.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/graphical-boot.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/networkmanager-wireguard.nix
    ../../modules/nixos/networkmanager-wifi.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/user-kyleh.nix
    ../../modules/nixos/workstation.nix
    ../../modules/nixos/zfs-root.nix
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        extraInstallCommands = ''
          ${pkgs.gnused}/bin/sed -i 's/^default .*/default @saved/' /boot/loader/loader.conf
        '';
        windows.windows = {
          title = "Windows";
          efiDeviceHandle = "FS2";
        };
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
    autoScrub = {
      enable = true;
      interval = "monthly";
    };

    trim = {
      enable = true;
      interval = "weekly";
    };
  };

  systemd.services.clear-ssh-control-sockets = {
    description = "Remove SSH control sockets before sleep";
    wantedBy = [ "sleep.target" ];
    before = [ "sleep.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = config.infrastructure.user.name;
    };

    script = ''
      socket_dir="${config.infrastructure.user.homeDirectory}/.cache/ssh"

      if [[ -d "$socket_dir" ]]; then
        ${pkgs.findutils}/bin/find "$socket_dir" \
          -maxdepth 1 -type s -name '*.sock' -delete
      fi
    '';
  };

  sops.defaultSopsFile = ../../secrets/pang14.yaml;

  home-manager.users.${config.infrastructure.user.name} = {
    imports = [
      ../../modules/home/kyleh/admin-tools.nix
      ../../modules/home/kyleh/development.nix
      ../../modules/home/kyleh/tmux.nix
    ];
    home.stateVersion = "26.05";
  };

  system.stateVersion = "26.05";
}
