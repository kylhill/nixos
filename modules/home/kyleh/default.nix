{ config, ... }:
{
  imports = [
    ./bash.nix
    ./desktop.nix
    ./git.nix
    ./infrastructure.nix
    ./neovim.nix
    ./ssh.nix
    ./tmux.nix
  ];

  home = {
    username = config.infrastructure.user.name;
    homeDirectory = config.infrastructure.user.homeDirectory;
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
}
