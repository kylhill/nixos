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
      pkgs.caladea
      pkgs.carlito
      pkgs.liberation_ttf
    ];

    fontconfig = {
      antialias = true;
      hinting = {
        enable = true;
        autohint = false;
        style = "full";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };

      localConf = ''
        <alias>
          <family>Arial</family>
          <prefer><family>Liberation Sans</family></prefer>
        </alias>
        <alias>
          <family>Calibri</family>
          <prefer><family>Carlito</family></prefer>
        </alias>
        <alias>
          <family>Cambria</family>
          <prefer><family>Caladea</family></prefer>
        </alias>
        <alias>
          <family>Times New Roman</family>
          <prefer><family>Liberation Serif</family></prefer>
        </alias>
        <alias>
          <family>Courier New</family>
          <prefer><family>Liberation Mono</family></prefer>
        </alias>
      '';
    };
  };
}
