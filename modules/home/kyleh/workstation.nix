_: {
  programs.bash.enableVteIntegration = true;

  imports = [
    ./applications.nix
    ./gnome-console.nix
    ./gnome.nix
  ];
}
