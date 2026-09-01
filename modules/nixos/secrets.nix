{
  config,
  host,
  inventory,
  ...
}:
let
  wifiSecretName = host.network.wifi.tacomafiaLan.secretName;
  sshDirectory = inventory.user.sshDirectory;
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
      ${wifiSecretName} = {
        mode = "0400";
        restartUnits = [ "nm-file-secret-agent.service" ];
      };
      "ssh/private-key" = {
        owner = inventory.user.name;
        group = "users";
        mode = "0600";
        path = "${sshDirectory}/id_ed25519";
      };
      "ssh/public-key" = {
        owner = inventory.user.name;
        group = "users";
        mode = "0644";
        path = "${sshDirectory}/id_ed25519.pub";
      };
    };
  };

  users = {
    mutableUsers = false;
    users.${inventory.user.name}.hashedPasswordFile = config.sops.secrets."user/password-hash".path;
  };
}
