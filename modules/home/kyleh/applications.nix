{ pkgs, ... }:
{
  home = {
    packages = [
      pkgs.hunspell
      pkgs.hunspellDicts.en_US
      pkgs.libreoffice
      pkgs.python3
    ];

    sessionVariables.ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };

  programs = {
    firefox = {
      enable = true;
      profiles.default = {
        id = 0;
        isDefault = true;
        settings = {
          "browser.backspace_action" = 0;
          "media.ffmpeg.vaapi.enabled" = true;
          "widget.use-xdg-desktop-portal.file-picker" = 1;
        };
      };
    };

    vscode.enable = true;
  };

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
      };
    };
  };
}
