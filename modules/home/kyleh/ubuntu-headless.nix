_: {
  imports = [ ./ubuntu.nix ];

  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.enable = false;
}
