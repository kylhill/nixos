{
  config,
  nix-index-database,
  nixvim,
  ...
}:
{
  home-manager.sharedModules = [
    nixvim.homeModules.nixvim
    nix-index-database.homeModules.default
    {
      infrastructure = {
        inherit (config.infrastructure) user network;
      };
    }
  ];

  sops.secrets."user/password-hash".neededForUsers = true;

  users = {
    mutableUsers = false;
    users.${config.infrastructure.user.name} = {
      isNormalUser = true;
      inherit (config.infrastructure.user) uid;
      description = config.infrastructure.user.fullName;
      extraGroups = [
        "dialout"
        "networkmanager"
        "video"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ config.infrastructure.user.sshPublicKey ];
      hashedPasswordFile = config.sops.secrets."user/password-hash".path;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    users.${config.infrastructure.user.name} = {
      imports = [ ../home/kyleh ];
    };
  };
}
