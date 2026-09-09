_: {
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/docker-tools.nix
    ../modules/home/kyleh/neovim-basic.nix
  ];

  targets.genericLinux = {
    enable = true;
  };
}
