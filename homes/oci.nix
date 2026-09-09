_: {
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/neovim-basic.nix
  ];

  targets.genericLinux = {
    enable = true;
  };
}
