{
  config,
  lib,
  ...
}:
let
  cfg = config.tacomafia.secrets;
  inventory = import ../../lib/inventory.nix;
in
{
  options.tacomafia.secrets = {
    enable = lib.mkEnableOption "host secrets managed by sops-nix";
    file = lib.mkOption {
      type = lib.types.path;
      description = "Path to the host's encrypted SOPS file.";
    };
  };

  config = lib.mkMerge [
    {
      warnings = lib.optional (!cfg.enable) ''
        pang14 secrets are not provisioned. The login password remains mutable and
        Wi-Fi and WireGuard profiles are disabled. Follow secrets/README.md before
        installation.
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
          "wifi/tacomafia-lan-password" = {
            mode = "0400";
            restartUnits = [
              "prepare-networkmanager-wifi-environment.service"
              "NetworkManager-ensure-profiles.service"
            ];
          };
          "ssh/private-key" = {
            owner = inventory.user.name;
            group = "users";
            mode = "0600";
            path = "/home/${inventory.user.name}/.ssh/id_ed25519";
          };
          "ssh/public-key" = {
            owner = inventory.user.name;
            group = "users";
            mode = "0644";
            path = "/home/${inventory.user.name}/.ssh/id_ed25519.pub";
          };
        };
      };

      users = {
        mutableUsers = false;
        users.${inventory.user.name}.hashedPasswordFile =
          config.sops.secrets."user/password-hash".path;
      };
    })
  ];
}
