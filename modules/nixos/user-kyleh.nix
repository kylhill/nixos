{
  config,
  inputs,
  latestPkgs,
  ...
}:
let
  user = config.infrastructure.user;
in
{
  sops.secrets = {
    "user/password-hash".neededForUsers = true;
    "ssh/private-key" = {
      sopsFile = ../../secrets/home.yaml;
      owner = user.name;
      group = "users";
      mode = "0600";
      path = "${user.sshDirectory}/id_ed25519";
    };
    "ssh/public-key" = {
      sopsFile = ../../secrets/home.yaml;
      owner = user.name;
      group = "users";
      mode = "0644";
      path = "${user.sshDirectory}/id_ed25519.pub";
    };
  };

  users = {
    mutableUsers = false;
    users.${config.infrastructure.user.name} = {
      isNormalUser = true;
      home = user.homeDirectory;
      inherit (config.infrastructure.user) uid;
      description = config.infrastructure.user.fullName;
      extraGroups = [
        "wheel"
      ];
      openssh.authorizedKeys.keys = [ config.infrastructure.user.sshPublicKey ];
      hashedPasswordFile = config.sops.secrets."user/password-hash".path;
    };
  };

  home-manager = {
    extraSpecialArgs = {
      inherit inputs latestPkgs;
      homeIdentity = {
        inherit (config.infrastructure.user) fullName email;
      };
      networkHosts = config.infrastructure.network.hosts;
    };
    useGlobalPkgs = true;
    users.${config.infrastructure.user.name} = {
      imports = [
        ../home/kyleh
        ../home/kyleh/nix-index.nix
      ];
    };
  };
}
