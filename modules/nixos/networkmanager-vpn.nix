{
  config,
  host,
  lib,
  ...
}:
let
  wg = host.network.wireguard;

  ipv4Address = addresses: lib.findFirst (address: !(lib.hasInfix ":" address)) null addresses;
  ipv6Address = addresses: lib.findFirst (address: lib.hasInfix ":" address) null addresses;

  mkWireGuardProfile = profile: {
    connection = {
      inherit (profile.connection) id uuid;
      type = "wireguard";
      interface-name = profile.connection.interfaceName;
      autoconnect = false;
      permissions = "";
    };

    wireguard = {
      private-key-flags = 1;
      peer-routes = true;
    };

    "wireguard-peer.${profile.publicKey}" = {
      inherit (profile) endpoint;
      preshared-key-flags = 1;
      persistent-keepalive = 25;
      allowed-ips = "0.0.0.0/0;::/0;";
    };

    ipv4 = {
      method = "manual";
      address1 = ipv4Address profile.addresses;
      dns = "${profile.dns};";
    };

    ipv6 = {
      method = "manual";
      address1 = ipv6Address profile.addresses;
    };
  };
in
{
  networking.networkmanager.ensureProfiles = {
    profiles = lib.listToAttrs (
      map (profile: lib.nameValuePair profile.connection.profileName (mkWireGuardProfile profile)) (
        builtins.attrValues wg
      )
    );

    secrets.entries = lib.concatMap (profile: [
      {
        matchId = profile.connection.id;
        matchType = "wireguard";
        matchSetting = "wireguard";
        key = "private-key";
        file = config.sops.secrets."wireguard/private-key".path;
      }
      {
        matchId = profile.connection.id;
        matchType = "wireguard";
        matchSetting = "wireguard-peer.${profile.publicKey}";
        key = "preshared-key";
        file = config.sops.secrets."wireguard/preshared-key".path;
      }
    ]) (builtins.attrValues wg);
  };

  systemd.services.nm-file-secret-agent = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
