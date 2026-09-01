{
  dircolorsSolarized,
  inventory,
  nixpkgsSource,
  ...
}:
{
  users = {
    users.${inventory.user.name} = {
      isNormalUser = true;
      uid = inventory.user.uid;
      description = inventory.user.fullName;
      extraGroups = [
        "dialout"
        "networkmanager"
        "video"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ inventory.user.sshPublicKey ];
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {
      inherit
        dircolorsSolarized
        inventory
        nixpkgsSource
        ;
    };
    users.${inventory.user.name} = {
      imports = [ ../home/kyleh ];
      home.stateVersion = "26.05";
    };
  };
}
