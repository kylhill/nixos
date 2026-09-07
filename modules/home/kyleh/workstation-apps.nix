{ latestPkgs, pkgs, ... }:
{
  home = {
    packages = [
      pkgs.hunspell
      pkgs.hunspellDicts.en_US
      pkgs.libreoffice
      # VS Code extensions and tasks need Python outside project environments.
      pkgs.python3
    ];
  };

  programs = {
    firefox = {
      enable = true;
      profiles.default = {
        id = 0;
        isDefault = true;
        settings = {
          "browser.backspace_action" = 0;
          "browser.display.use_document_fonts" = 1;
          "font.default.x-western" = "sans-serif";
          "font.size.fixed.x-western" = 13;
          "font.size.variable.x-western" = 16;
          "media.ffmpeg.vaapi.enabled" = true;
          "widget.use-xdg-desktop-portal.file-picker" = 1;
        };
      };
    };

    vscode = {
      enable = true;
      package = latestPkgs.vscode;
    };
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
