{
  config,
  pkgs,
  ...
}:
{
  nixpkgs.overlays = [
    (_final: prev: {
      gnome-console = prev.gnome-console.overrideAttrs (oldAttrs: {
        # Console 50 uses a tuple format while iterating its a{sv} custom
        # livery dictionary, causing every custom palette to be rejected.
        postPatch = (oldAttrs.postPatch or "") + ''
          substituteInPlace src/kgx-livery-manager.c \
            --replace-fail 'g_variant_iter_next (iter, "(&sv)"' \
                           'g_variant_iter_next (iter, "{&sv}"'
        '';
      });
    })
  ];

  console.colors = [
    "002b36"
    "dc322f"
    "859900"
    "b58900"
    "268bd2"
    "d33682"
    "2aa198"
    "93a1a1"
    "657b83"
    "dc322f"
    "859900"
    "b58900"
    "268bd2"
    "d33682"
    "2aa198"
    "fdf6e3"
  ];

  home-manager.users.${config.infrastructure.user.name}.imports = [ ../home/kyleh/workstation.nix ];

  users.users.${config.infrastructure.user.name}.extraGroups = [
    "networkmanager"
    "video"
  ];

  networking = {
    modemmanager.enable = false;
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

    colord.enable = false;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    dleyna.enable = false;
    geoclue2.enable = false;
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

    xwayland.enable = false;
  };

  environment = {
    gnome.excludePackages = with pkgs; [
      epiphany
      gnome-connections
      gnome-maps
      gnome-tour
      gnome-user-docs
      orca
      simple-scan
      yelp
    ];

    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };

    systemPackages = [
      pkgs.file-roller
      pkgs.unzip
    ];
  };

  fonts = {
    packages = [
      # Modern desktop fonts
      pkgs.adwaita-fonts
      pkgs.nerd-fonts.caskaydia-cove

      # Broad Unicode coverage
      pkgs.noto-fonts
      pkgs.noto-fonts-cjk-sans
      pkgs.noto-fonts-cjk-serif
      pkgs.noto-fonts-color-emoji

      # Linux / legacy fallback
      pkgs.dejavu_fonts

      # Microsoft metric-compatible fonts
      pkgs.carlito
      pkgs.caladea
      pkgs.liberation_ttf

      # Classic document/PostScript compatibility
      pkgs.gyre-fonts

      # Actual Microsoft fonts
      pkgs.corefonts
      pkgs.vista-fonts
    ];

    fontconfig = {
      antialias = true;
      defaultFonts = {
        sansSerif = [
          "Adwaita Sans"
          "Noto Sans"
          "DejaVu Sans"
        ];

        serif = [
          "Noto Serif"
          "DejaVu Serif"
        ];

        monospace = [
          "CaskaydiaCove Nerd Font Mono"
          "Noto Sans Mono"
          "DejaVu Sans Mono"
        ];

        emoji = [ "Noto Color Emoji" ];
      };
      hinting = {
        enable = true;
        autohint = false;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };
}
