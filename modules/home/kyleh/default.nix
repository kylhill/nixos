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
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
