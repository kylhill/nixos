{
  config,
  lib,
  ...
}:
{
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocales = [ ];
  };

  nix = {
    channel.enable = false;

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
      "corefonts"
      "github-copilot-cli"
      "vista-fonts"
      "vscode"
    ];

  time.timeZone = config.infrastructure.host.timeZone;
}
