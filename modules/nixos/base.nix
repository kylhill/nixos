{
  host,
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
      warn-dirty = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise = {
      automatic = true;
      dates = "weekly";
    };
  };

  nixpkgs.config.allowUnfree = true;

  time.timeZone = host.timeZone;

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
    wget
  ];
}
