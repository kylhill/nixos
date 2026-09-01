{
  config,
  inventory,
  lib,
  ...
}:
let
  wg = inventory.network.wireguard;

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
      peer-routes = true;
    };

    "wireguard-peer.${profile.publicKey}" = {
      inherit (profile) endpoint;
      preshared-key = "$WIREGUARD_PRESHARED_KEY";
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
  sops.templates."networkmanager-wireguard.env" = {
    content = ''
      WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."wireguard/private-key"}
      WIREGUARD_PRESHARED_KEY=${config.sops.placeholder."wireguard/preshared-key"}
    '';
    mode = "0400";
    restartUnits = [ "NetworkManager-ensure-profiles.service" ];
  };

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.templates."networkmanager-wireguard.env".path ];
    profiles = lib.listToAttrs (
      map (profile: lib.nameValuePair profile.connection.profileName (mkWireGuardProfile profile)) (
        builtins.attrValues wg
      )
    );
  };

  systemd.services.NetworkManager-ensure-profiles = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };
}
