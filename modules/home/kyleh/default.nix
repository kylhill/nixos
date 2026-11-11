{ lib, ... }: {
  _module.args.wslAgent = lib.mkDefault false;
  imports = [
    ./bash.nix
    ./git.nix
    ./htop.nix
    ./ssh.nix
  ];

  home = {
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
}
