{
  pkgs,
  tinted-schemes,
  ...
}:
{
  stylix = {
    enable = true;
    base16Scheme = "${tinted-schemes}/base16/solarized-dark.yaml";
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
