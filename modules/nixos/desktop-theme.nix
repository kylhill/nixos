{ pkgs, ... }:
{
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

  fonts = {
    packages = [
      pkgs.dejavu_fonts
      pkgs.nerd-fonts.caskaydia-cove
      pkgs.noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      emoji = [ "Noto Color Emoji" ];
      monospace = [ "CaskaydiaCove Nerd Font Mono" ];
      sansSerif = [ "DejaVu Sans" ];
      serif = [ "DejaVu Serif" ];
    };
  };
}
