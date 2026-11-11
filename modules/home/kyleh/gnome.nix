{ lib, pkgs, ... }:
let
  inherit (lib.hm.gvariant)
    mkArray
    mkDictionaryEntry
    mkDouble
    mkTuple
    mkUint32
    mkVariant
    ;

  colors = import ./solarized.nix;
  solarizedDarkUuid = "043f5921-e1fb-4f08-91b1-6f9e936b85a7";
  rgb =
    name:
    mkTuple (
      map (offset: mkDouble (lib.fromHexString (builtins.substring offset 2 colors.${name}) / 255.0)) [
        1
        3
        5
      ]
    );
  dictionary =
    attrs:
    mkArray "{sv}" (
      lib.mapAttrsToList (
        name: value:
        mkDictionaryEntry [
          name
          (mkVariant value)
        ]
      ) attrs
    );
  palette = dictionary {
    foreground = rgb "base0";
    background = rgb "base03";
    transparency = mkDouble 0.0;
    colours = mkArray "(ddd)" (
      map rgb [
        "base02"
        "red"
        "green"
        "yellow"
        "blue"
        "magenta"
        "cyan"
        "base2"
        "base03"
        "orange"
        "base01"
        "base00"
        "base0"
        "violet"
        "base1"
        "base3"
      ]
    );
  };
in
{
  dconf.settings = {
    "org/gnome/desktop/background" = {
      picture-uri = "file://${pkgs.gnome-backgrounds}/share/backgrounds/gnome/pixel-pusher-d.jxl";
      picture-uri-dark = "file://${pkgs.gnome-backgrounds}/share/backgrounds/gnome/pixel-pusher-d.jxl";
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
      clock-show-weekday = true;
      color-scheme = "prefer-dark";
      font-antialiasing = "rgba";
      monospace-font-name = "CaskaydiaCove Nerd Font Mono 10";
    };

    "org/gnome/desktop/privacy" = {
      old-files-age = mkUint32 14;
      recent-files-max-age = 30;
      remove-old-temp-files = true;
      remove-old-trash-files = true;
    };

    "org/gnome/desktop/peripherals/keyboard".numlock-state = true;
    "org/gnome/desktop/sound".event-sounds = false;

    "org/gnome/TextEditor" = {
      highlight-current-line = true;
      indent-style = "space";
      show-line-numbers = true;
      show-right-margin = false;
      style-scheme = "solarized-dark";
      tab-width = mkUint32 4;
      use-system-font = true;
      wrap-text = false;
    };

    "org/gnome/desktop/wm/keybindings" = {
      minimize = [ ];
      show-desktop = [ "<Super>d" ];
      switch-applications = [ ];
      switch-applications-backward = [ ];
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
    };
    "org/gnome/desktop/wm/preferences".button-layout = "appmenu:minimize,close";
    "org/gnome/nautilus/preferences".default-folder-viewer = "list-view";

    "org/gnome/Console" = {
      custom-liveries = dictionary {
        ${solarizedDarkUuid} = dictionary {
          uuid = solarizedDarkUuid;
          name = "Solarized Dark";
          night = palette;
        };
      };
      ignore-scrollback-limit = true;
      livery = solarizedDarkUuid;
    };

    "org/gnome/mutter".workspaces-only-on-primary = false;

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/console/"
      ];
      home = [ "<Super>e" ];
      www = [ "<Super>f" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/console" = {
      binding = "<Super>t";
      command = "kgx";
      name = "GNOME Console";
    };

    "org/gnome/settings-daemon/plugins/color" = {
      night-light-enabled = true;
      night-light-temperature = mkUint32 4000;
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
