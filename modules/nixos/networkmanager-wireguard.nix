{
  config,
  lib,
  ...
}:
let
  wg = config.infrastructure.host.network.wireguard;
  unique = values: builtins.length values == builtins.length (lib.unique values);
  decimal = value: builtins.match "[0-9]+" value != null;
  decimalBetween =
    minimum: maximum: value:
    decimal value && lib.toInt value >= minimum && lib.toInt value <= maximum;
  validIPv4 =
    address:
    let
      octets = lib.splitString "." address;
    in
    builtins.length octets == 4 && builtins.all (decimalBetween 0 255) octets;
  validIPv4Cidr =
    address:
    let
      parts = lib.splitString "/" address;
    in
    builtins.length parts == 2
    && validIPv4 (builtins.elemAt parts 0)
    && decimalBetween 0 32 (builtins.elemAt parts 1);
  validIPv6 =
    address:
    !lib.hasInfix "/" address
    && (builtins.tryEval (builtins.deepSeq (lib.network.ipv6.fromString address) true)).success;
  validIPv6Cidr =
    address:
    lib.hasInfix "/" address
    && (builtins.tryEval (builtins.deepSeq (lib.network.ipv6.fromString address) true)).success;
  ipAddressType = lib.types.addCheck lib.types.str (address: validIPv4 address || validIPv6 address);
  interfaceNameType = lib.types.addCheck lib.types.str (
    name: builtins.stringLength name <= 15 && builtins.match "[A-Za-z0-9_.-]+" name != null
  );
  cidrType = lib.types.addCheck lib.types.str (
    address: validIPv4Cidr address || validIPv6Cidr address
  );
  secretNameType = lib.types.strMatching "[A-Za-z0-9._/-]+";
  wireGuardKeyType = lib.types.strMatching "[A-Za-z0-9+/]{43}=";
  endpointType = lib.types.addCheck lib.types.str (
    endpoint:
    let
      match = builtins.match ".+:([0-9]+)" endpoint;
    in
    match != null
    && lib.toInt (builtins.elemAt match 0) > 0
    && lib.toInt (builtins.elemAt match 0) <= 65535
  );

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

    ipv6 =
      let
        address = ipv6Address profile.addresses;
      in
      if address == null then
        { method = "disabled"; }
      else
        {
          method = "manual";
          address1 = address;
        };
  };
in
{
  options.infrastructure.host.network.wireguard = lib.mkOption {
    default = { };
    description = "WireGuard profiles managed declaratively by NetworkManager.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          connection = lib.mkOption {
            description = "NetworkManager identity for this WireGuard profile.";
            type = lib.types.submodule {
              options = {
                id = lib.mkOption {
                  type = lib.types.str;
                  description = "NetworkManager WireGuard connection ID.";
                };
                uuid = lib.mkOption {
                  type = lib.types.strMatching "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}";
                  description = "Stable NetworkManager connection UUID.";
                };
                interfaceName = lib.mkOption {
                  type = interfaceNameType;
                  description = "Stable WireGuard interface name.";
                };
              };
            };
          };
          endpoint = lib.mkOption {
            type = endpointType;
            description = "WireGuard peer endpoint in host:port form.";
          };
          publicKey = lib.mkOption {
            type = wireGuardKeyType;
            description = "Public key of the WireGuard peer.";
          };
          privateKeySecretName = lib.mkOption {
            type = secretNameType;
            description = "sops-nix secret containing the local WireGuard private key.";
          };
          presharedKeySecretName = lib.mkOption {
            type = secretNameType;
            description = "sops-nix secret containing the WireGuard preshared key.";
          };
          dns = lib.mkOption {
            type = ipAddressType;
            description = "DNS server used while this profile is active.";
          };
          addresses = lib.mkOption {
            type = lib.types.listOf cidrType;
            description = "Local IPv4 and optional IPv6 interface addresses in CIDR notation.";
          };
        };
      }
    );
  };

  config = {
    assertions = [
      {
        assertion = unique (map (profile: profile.connection.id) (builtins.attrValues wg));
        message = "NetworkManager WireGuard connection IDs must be unique.";
      }
      {
        assertion = unique (map (profile: profile.connection.uuid) (builtins.attrValues wg));
        message = "NetworkManager WireGuard profile UUIDs must be unique.";
      }
      {
        assertion = unique (map (profile: profile.connection.interfaceName) (builtins.attrValues wg));
        message = "NetworkManager WireGuard interface names must be unique.";
      }
      {
        assertion = builtins.all (name: builtins.match "[A-Za-z0-9_.-]+" name != null) (
          builtins.attrNames wg
        );
        message = "NetworkManager WireGuard profile names may contain only letters, digits, dots, underscores, and hyphens.";
      }
    ]
    ++ lib.concatMap (profile: [
      {
        assertion =
          builtins.length (lib.filter validIPv4Cidr profile.addresses) == 1
          && builtins.length (lib.filter validIPv6Cidr profile.addresses) <= 1;
        message = "Each WireGuard profile must have exactly one IPv4 address and at most one IPv6 address.";
      }
      {
        assertion = profile.privateKeySecretName != profile.presharedKeySecretName;
        message = "A WireGuard profile must use different private-key and preshared-key secrets.";
      }
    ]) (builtins.attrValues wg);

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

    networking.networkmanager = {
      enable = true;
      ensureProfiles = {
        profiles = lib.mapAttrs (_: mkWireGuardProfile) wg;

        environmentFiles = lib.mapAttrsToList (
          name: _: config.sops.templates."networkmanager-wireguard-${name}.env".path
        ) wg;
      };
    };
  };
}
