{
  config,
  lib,
  ...
}:
let
  wg = config.infrastructure.host.network.wireguard;

  ipv4Address = addresses: lib.findFirst (address: !(lib.hasInfix ":" address)) null addresses;
  ipv6Address = addresses: lib.findFirst (address: lib.hasInfix ":" address) null addresses;
  variableSuffix = profile: lib.replaceStrings [ "-" ] [ "_" ] profile.connection.uuid;
  privateKeyVariable = profile: "WIREGUARD_PRIVATE_KEY_${variableSuffix profile}";
  presharedKeyVariable = profile: "WIREGUARD_PRESHARED_KEY_${variableSuffix profile}";
  dollar = "$";

  mkWireGuardProfile = profile: {
    connection = {
      inherit (profile.connection) id uuid;
      type = "wireguard";
      interface-name = profile.connection.interfaceName;
      autoconnect = false;
      permissions = "";
    };

    wireguard = {
      private-key = "${dollar}${privateKeyVariable profile}";
      private-key-flags = 0;
      peer-routes = true;
    };

    "wireguard-peer.${profile.publicKey}" = {
      inherit (profile) endpoint;
      preshared-key = "${dollar}${presharedKeyVariable profile}";
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
  sops.secrets = lib.listToAttrs (
    lib.concatMap (profile: [
      (lib.nameValuePair profile.privateKeySecretName {
        mode = "0400";
        restartUnits = [ "NetworkManager-ensure-profiles.service" ];
      })
      (lib.nameValuePair profile.presharedKeySecretName {
        mode = "0400";
        restartUnits = [ "NetworkManager-ensure-profiles.service" ];
      })
    ]) (builtins.attrValues wg)
  );

  sops.templates = lib.mapAttrs' (
    name: profile:
    lib.nameValuePair "networkmanager-wireguard-${name}.env" {
      content = ''
        ${privateKeyVariable profile}=${config.sops.placeholder.${profile.privateKeySecretName}}
        ${presharedKeyVariable profile}=${config.sops.placeholder.${profile.presharedKeySecretName}}
      '';
      mode = "0400";
    }
  ) wg;

  networking.networkmanager.ensureProfiles = {
    profiles = lib.listToAttrs (
      map (profile: lib.nameValuePair profile.connection.profileName (mkWireGuardProfile profile)) (
        builtins.attrValues wg
      )
    );

    environmentFiles = lib.mapAttrsToList (
      name: _: config.sops.templates."networkmanager-wireguard-${name}.env".path
    ) wg;
  };
}
