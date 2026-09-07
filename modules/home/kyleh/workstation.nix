_: {
  programs.bash.enableVteIntegration = true;

  imports = [
    ./gnome.nix
    ./workstation-apps.nix
  ];
}
