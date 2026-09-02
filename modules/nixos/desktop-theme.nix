{
  pkgs,
  inputs,
  ...
}:
{
  stylix = {
    enable = true;
    base16Scheme = "${inputs.tinted-schemes}/base16/solarized-dark.yaml";
    image = "${pkgs.gnome-backgrounds}/share/backgrounds/gnome/pixel-pusher-d.jxl";
    polarity = "dark";
    opacity.terminal = 0.95;

    fonts.monospace = {
      package = pkgs.nerd-fonts.caskaydia-cove;
      name = "CaskaydiaCove Nerd Font Mono";
    };
    fonts.sizes = {
      applications = 11;
      terminal = 10;
    };
  };
}
