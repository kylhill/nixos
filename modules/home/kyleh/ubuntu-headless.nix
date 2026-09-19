_: {
  imports = [ ./ubuntu.nix ];

  manual.manpages.enable = false;
  targets.genericLinux.enable = true;
  programs.nixvim.waylandSupport = false;
}
