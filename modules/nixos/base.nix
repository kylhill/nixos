{
  config,
  lib,
  pkgs,
  ...
}:
let
  inventory = import ../../lib/inventory.nix;
in
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      warn-dirty = false;
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
    firewall.enable = true;
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users = {
    mutableUsers = true;
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
      shell = pkgs.bashInteractive;
    };
  };

  security = {
    rtkit.enable = true;
    sudo.wheelNeedsPassword = true;
  };

  programs = {
    bash.completion.enable = true;
    dconf.enable = true;
  };

  environment.systemPackages = with pkgs; [
    btop
    curl
    git
    htop
    ncdu
    nvme-cli
    powertop
    smartmontools
    vim
    wireguard-tools
  ];

  system.stateVersion = "26.05";
}
