_: {
  imports = [ ./ubuntu.nix ];

  targets.genericLinux.enable = true;
  programs.nixvim.waylandSupport = false;
}
