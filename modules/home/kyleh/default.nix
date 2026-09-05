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
    inherit (homeIdentity) homeDirectory;
    preferXdgDirectories = true;
  };

  programs.home-manager.enable = true;
}
