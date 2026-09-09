{
  homeIdentity,
  isStandaloneHome,
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

  services.home-manager.autoExpire = {
    enable = true;
    frequency = "weekly";
    timestamp = "-7 days";
    store.cleanup = isStandaloneHome;
  };

  targets.genericLinux.gpu.enable = false;
}
