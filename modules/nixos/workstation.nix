{ pkgs, ... }:
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
    gnome.gcr-ssh-agent.enable = true;
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    xserver.enable = false;
  };

  programs.xwayland.enable = true;

  environment = {
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };

    systemPackages = [
      pkgs.gnome-tweaks
      pkgs.wireguard-tools
    ];
  };
}
