{ lib, ... }:
{
  dconf.settings = {
    "org/gnome/desktop/datetime".automatic-timezone = true;

    "org/gnome/desktop/input-sources".sources = [
      (lib.hm.gvariant.mkTuple [
        "xkb"
        "us"
      ])
    ];

    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      show-battery-percentage = true;
    };

    "org/gnome/desktop/privacy" = {
      old-files-age = 14;
      recent-files-max-age = 30;
      remove-old-temp-files = true;
      remove-old-trash-files = true;
    };

    "org/gnome/desktop/peripherals/keyboard".numlock-state = true;
    "org/gnome/desktop/screensaver".lock-delay = 0;
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
