_: {
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/ubuntu.nix
  ];

  targets.genericLinux = {
    enable = true;
  };

  programs.nixvim.waylandSupport = false;
}
