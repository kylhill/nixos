{
  inputs,
  homeIdentity,
  ...
}:
{
  imports = [
    inputs.nix-index-database.homeModules.default
    ./bash.nix
    ./git.nix
    ./htop.nix
    ./ssh.nix
  ];

  home = {
    username = homeIdentity.name;
    homeDirectory = homeIdentity.homeDirectory;
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
}
