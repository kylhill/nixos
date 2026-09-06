_: {
  programs.bash.enableVteIntegration = true;

  imports = [
    ./gnome.nix
    ./gnome-console.nix
    ./workstation-apps.nix
  ];
}
