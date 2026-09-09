{
  homeIdentity,
  ...
}:
{
  imports = [
    ./admin-tools.nix
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

  targets.genericLinux.gpu.enable = false;
}
