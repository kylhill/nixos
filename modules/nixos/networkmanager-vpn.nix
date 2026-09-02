{
  config,
  lib,
  ...
}:
let
  wg = config.infrastructure.host.network.wireguard;

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
      private-key = "$WIREGUARD_PRIVATE_KEY";
      private-key-flags = 0;
      peer-routes = true;
    };

    "wireguard-peer.${profile.publicKey}" = {
      inherit (profile) endpoint;
      preshared-key = "$WIREGUARD_PRESHARED_KEY";
      preshared-key-flags = 0;
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

  };

}
