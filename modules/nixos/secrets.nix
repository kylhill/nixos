{
  config,
  inventory,
  ...
}:
{
  sops = {
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      "user/password-hash".neededForUsers = true;
      "wireguard/private-key".mode = "0400";
      "wireguard/preshared-key".mode = "0400";
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
    users.${inventory.user.name}.hashedPasswordFile = config.sops.secrets."user/password-hash".path;
  };
}
