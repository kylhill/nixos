{ pkgs, ... }:
{
  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };

  programs = {
    firefox = {
      enable = true;
      profiles.default = {
        id = 0;
        isDefault = true;
        settings = {
          "browser.tabs.warnOnClose" = true;
          "media.ffmpeg.vaapi.enabled" = true;
          "widget.use-xdg-desktop-portal.file-picker" = 1;
        };
      };
    };

    vscode = {
      enable = true;
      package = pkgs.vscode;
      mutableExtensionsDir = true;
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

  dconf.settings = {
    "org/gnome/Console" = {
      custom-font = "CaskaydiaCove Nerd Font 10";
      ignore-scrollback-limit = true;
      use-system-font = false;
    };

    "org/gnome/desktop/datetime".automatic-timezone = true;

    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      color-scheme = "prefer-dark";
      show-battery-percentage = true;
    };

    "org/gnome/desktop/privacy" = {
      old-files-age = 14;
      recent-files-max-age = 30;
      remove-old-temp-files = true;
      remove-old-trash-files = true;
    };

    "org/gnome/desktop/screensaver".lock-delay = 0;
    "org/gnome/desktop/sound".event-sounds = false;
    "org/gnome/desktop/wm/keybindings".show-desktop = [ "<Super>d" ];
    "org/gnome/nautilus/preferences".default-folder-viewer = "list-view";

    "org/gnome/settings-daemon/plugins/media-keys" = {
      home = [ "<Super>h" ];
      www = [ "<Super>f" ];
    };

    "org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-timeout = 3600;
    "org/gnome/system/location".enabled = true;

    "org/gnome/shell".favorite-apps = [
      "firefox.desktop"
      "org.gnome.Nautilus.desktop"
      "org.gnome.Console.desktop"
      "code.desktop"
    ];
  };
}
