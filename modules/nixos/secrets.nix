{
  config,
  lib,
  ...
}:
let
  inherit (config.infrastructure) user;
  wifiProfiles = config.infrastructure.host.network.wifi;
in
{
  sops = {
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      "user/password-hash".neededForUsers = true;
      "wireguard/private-key" = {
        mode = "0400";
        restartUnits = [ "nm-file-secret-agent.service" ];
      };
      "wireguard/preshared-key" = {
        mode = "0400";
        restartUnits = [ "nm-file-secret-agent.service" ];
      };
    }
    // lib.mapAttrs' (
      _: wifi:
      lib.nameValuePair wifi.secretName {
        mode = "0400";
        restartUnits = [ "nm-file-secret-agent.service" ];
      }
    ) wifiProfiles
    // {
      "ssh/private-key" = {
        owner = user.name;
        group = "users";
        mode = "0600";
        path = "${user.sshDirectory}/id_ed25519";
      };
      "ssh/public-key" = {
        owner = user.name;
        group = "users";
        mode = "0644";
        path = "${user.sshDirectory}/id_ed25519.pub";
      };
    };
  };

  users = {
    mutableUsers = false;
    users.${user.name}.hashedPasswordFile = config.sops.secrets."user/password-hash".path;
  };
}
