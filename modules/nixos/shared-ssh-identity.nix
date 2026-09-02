{ config, ... }:
let
  inherit (config.infrastructure) user;
in
{
  sops.secrets = {
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
}
