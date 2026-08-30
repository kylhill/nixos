{ pkgs, ... }:
{
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    xserver.enable = false;
    gnome.gnome-keyring.enable = true;
  };

  programs.xwayland.enable = false;

  environment = {
    sessionVariables = {
      GDK_BACKEND = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
    };

    systemPackages = with pkgs; [
      gnome-terminal
      gnome-tweaks
    ];
  };
}
