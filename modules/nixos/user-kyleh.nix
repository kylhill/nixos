{
  config,
  ...
}:
{
  home-manager.sharedModules = [
    {
      infrastructure = {
        inherit (config.infrastructure) user network;
      };
    }
  ];

  users = {
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
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "hm-backup";
    users.${config.infrastructure.user.name} = {
      imports = [ ../home/kyleh ];
      home.stateVersion = "26.05";
    };
  };
}
