_: {
  imports = [
    ./bash.nix
    ./git.nix
    ./htop.nix
    ./neovim.nix
    ./ssh.nix
  ];

  home = {
    enableNixpkgsReleaseCheck = false;
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
  targets.genericLinux.gpu.enable = false;
}
