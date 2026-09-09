_: {
  imports = [
    ../modules/home/kyleh
  ];

  targets.genericLinux = {
    enable = true;
  };

  programs.nixvim.waylandSupport = false;
}
