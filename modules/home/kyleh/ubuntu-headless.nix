_: {
  imports = [ ./ubuntu.nix ];

  manual.manpages.enable = false;
  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.enable = false;
  programs.nixvim.waylandSupport = false;
}
