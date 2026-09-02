{ config, ... }:
{
  imports = [
    ./bash.nix
    ./desktop.nix
    ./git.nix
    ./infrastructure.nix
    ./neovim.nix
    ./ssh.nix
  ];

  home = {
    username = config.infrastructure.user.name;
    homeDirectory = config.infrastructure.user.homeDirectory;
    preferXdgDirectories = true;
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
