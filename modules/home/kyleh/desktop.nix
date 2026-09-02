{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.hm.gvariant)
    mkArray
    mkDictionaryEntry
    mkDouble
    mkTuple
    mkVariant
    ;

  colors = config.lib.stylix.colors;
  solarizedDarkUuid = "043f5921-e1fb-4f08-91b1-6f9e936b85a7";
  rgb =
    name:
    mkTuple (
      map mkDouble [
        (lib.toInt colors."${name}-rgb-r" / 255.0)
        (lib.toInt colors."${name}-rgb-g" / 255.0)
        (lib.toInt colors."${name}-rgb-b" / 255.0)
      ]
    );
  dictionary =
    entries:
    mkArray "{sv}" (
      map (
        entry:
        mkDictionaryEntry [
          entry.name
          (mkVariant entry.value)
        ]
      ) entries
    );
  palette = dictionary [
    {
      name = "foreground";
      value = rgb "base04";
    }
    {
      name = "background";
      value = rgb "base00";
    }
    {
      name = "transparency";
      value = mkDouble (1.0 - config.stylix.opacity.terminal);
    }
    {
      name = "colours";
      value = mkArray "(ddd)" (
        map rgb [
          "base01"
          "base08"
          "base0B"
          "base0A"
          "base0D"
          "base0F"
          "base0C"
          "base06"
          "base00"
          "base09"
          "base02"
          "base03"
          "base04"
          "base0E"
          "base05"
          "base07"
        ]
      );
    }
  ];
in
{
  stylix.targets = {
    firefox.enable = false;
    qt.enable = false;
    vscode.enable = false;
  };

  home = {
    packages = [
      pkgs.hunspell
      pkgs.hunspellDicts.en_US
      pkgs.libreoffice
      pkgs.python3
    ];

    sessionVariables = {
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };
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

  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/pixel-pusher-l.jxl";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/pixel-pusher-d.jxl";
      primary-color = "#967864";
      secondary-color = "#000000";
    };

    "org/gnome/Console" = {
      custom-font = "${config.stylix.fonts.monospace.name} ${toString config.stylix.fonts.sizes.terminal}";
      custom-liveries = dictionary [
        {
          name = solarizedDarkUuid;
          value = dictionary [
            {
              name = "uuid";
              value = solarizedDarkUuid;
            }
            {
              name = "name";
              value = "Solarized Dark";
            }
            {
              name = "night";
              value = palette;
            }
          ];
        }
      ];
      ignore-scrollback-limit = true;
      livery = solarizedDarkUuid;
      theme = "night";
      transparency = true;
      use-system-font = false;
    };

    "org/gnome/desktop/datetime".automatic-timezone = true;

    "org/gnome/desktop/input-sources".sources = [
      (lib.hm.gvariant.mkTuple [
        "xkb"
        "us"
      ])
    ];

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

    "org/gnome/desktop/peripherals/keyboard".numlock-state = true;

    "org/gnome/desktop/screensaver" = {
      lock-delay = 0;
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/pixel-pusher-l.jxl";
      primary-color = "#967864";
      secondary-color = "#000000";
    };

    "org/gnome/desktop/sound".event-sounds = false;
    "org/gnome/desktop/wm/keybindings" = {
      minimize = [ ];
      show-desktop = [ "<Super>d" ];
    };
    "org/gnome/desktop/wm/preferences".button-layout = "appmenu:minimize,close";
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
