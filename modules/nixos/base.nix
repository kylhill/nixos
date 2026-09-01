{
  inventory,
  pkgs,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      warn-dirty = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  networking = {
    networkmanager.enable = true;
    nftables.enable = true;
  };

  time.timeZone = "America/Chicago";

  users = {
    users.${inventory.user.name} = {
      isNormalUser = true;
      uid = inventory.user.uid;
      description = inventory.user.fullName;
      extraGroups = [
        "dialout"
        "networkmanager"
        "video"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ inventory.user.sshPublicKey ];
    };
  };

  security.rtkit.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    iotop
    lsof
    ncdu
    nvme-cli
    powertop
    rsync
    wireguard-tools
    wget
  ];

  system.stateVersion = "26.05";
}
