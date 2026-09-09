_: {
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/docker-tools.nix
  ];

  targets.genericLinux = {
    enable = true;
  };

  programs.nixvim.waylandSupport = false;
}
