{ osConfig, ... }:
{
  imports = [
    ./bash.nix
    ./git.nix
    ./htop.nix
    ./neovim.nix
    ./ssh.nix
  ];

  home = {
    username = osConfig.infrastructure.user.name;
    homeDirectory = osConfig.infrastructure.user.homeDirectory;
    preferXdgDirectories = true;
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
