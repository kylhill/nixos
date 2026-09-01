{
  config,
  lib,
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

  nixpkgs.config.allowUnfreePredicate =
    package:
    builtins.elem (lib.getName package) [
      "github-copilot-cli"
      "vscode"
    ];

  time.timeZone = config.infrastructure.host.timeZone;

  environment.systemPackages = [
    pkgs.curl
    pkgs.git
    pkgs.htop
    pkgs.iotop
    pkgs.lsof
    pkgs.ncdu
    pkgs.nvme-cli
    pkgs.powertop
    pkgs.rsync
    pkgs.wget
  ];
}
