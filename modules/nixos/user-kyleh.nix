{
  config,
  inputs,
  pkgs,
  ...
}:
let
  latestPkgs = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate =
      package:
      builtins.elem (pkgs.lib.getName package) [
        "github-copilot-cli"
        "vscode"
      ];
  };
in
{
  sops.secrets."user/password-hash".neededForUsers = true;

  users = {
    mutableUsers = false;
    users.${config.infrastructure.user.name} = {
      isNormalUser = true;
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
        inherit (config.infrastructure.user)
          name
          fullName
          email
          homeDirectory
          ;
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
