{ ... }:
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
    username = "kyleh";
    homeDirectory = "/home/kyleh";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
