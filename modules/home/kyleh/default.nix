_: {
  imports = [
    ./bash.nix
    ./git.nix
    ./htop.nix
    ./neovim.nix
    ./ssh.nix
  ];

  home = {
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
  targets.genericLinux.gpu.enable = false;
}
