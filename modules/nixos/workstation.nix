{
  lib,
  pkgs,
  ...
}:
let
  gstreamerPackages = with pkgs.gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ];
  gstreamerPluginPath = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstreamerPackages;
in
{
  networking = {
    networkmanager.enable = true;
    nftables.enable = true;
  };

  security.rtkit.enable = true;

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    dleyna.enable = false;
    gnome = {
      gcr-ssh-agent.enable = true;
      gnome-remote-desktop.enable = false;
      gnome-user-share.enable = false;
      rygel.enable = false;
    };
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    xserver.enable = false;
  };

  programs = {
    nautilus-open-any-terminal = {
      enable = true;
      terminal = "kgx";
    };

    xwayland.enable = true;
  };

  environment = {
    gnome.excludePackages = with pkgs; [
      epiphany
      gnome-connections
      gnome-maps
      gnome-tour
      simple-scan
    ];

    sessionVariables = {
      GST_PLUGIN_SYSTEM_PATH_1_0 = gstreamerPluginPath;
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };

    systemPackages = gstreamerPackages ++ [
      pkgs.file-roller
      pkgs.unzip
    ];
  };

  fonts.packages = [
    pkgs.caladea
    pkgs.carlito
    pkgs.liberation_ttf
  ];
}
