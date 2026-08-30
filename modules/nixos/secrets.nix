{
  config,
  lib,
  ...
}:
let
  cfg = config.tacomafia.secrets;
in
{
  options.tacomafia.secrets = {
    enable = lib.mkEnableOption "host secrets managed by sops-nix";
    file = lib.mkOption {
      type = lib.types.str;
      description = "Absolute path to the host's encrypted SOPS file.";
    };
  };

  config = lib.mkMerge [
    {
      warnings = lib.optional (!cfg.enable) ''
        pang14 secrets are not provisioned. The login password remains mutable and
        WireGuard profiles are disabled. Follow secrets/README.md before installation.
      '';
    }

    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = builtins.pathExists cfg.file;
          message = "tacomafia.secrets.enable requires the encrypted host secrets file";
        }
      ];

      sops = {
        defaultSopsFile = cfg.file;
        defaultSopsFormat = "yaml";
        age.keyFile = "/var/lib/sops-nix/key.txt";

        secrets = {
          "user/password-hash" = {
            neededForUsers = true;
          };
          "wireguard/private-key" = {
            mode = "0400";
          };
          "wireguard/preshared-key" = {
            mode = "0400";
          };
        };
      };

      users.users.kyleh.hashedPasswordFile = config.sops.secrets."user/password-hash".path;
    })
  ];
}
