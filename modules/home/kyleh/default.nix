{ inventory, ... }:
{
  imports = [
    ./bash.nix
    ./desktop.nix
    ./git.nix
    ./neovim.nix
    ./ssh.nix
    ./tmux.nix
  ];

  home = {
    username = inventory.user.name;
    homeDirectory = inventory.user.homeDirectory;
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
}
