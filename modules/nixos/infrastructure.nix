{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.infrastructure;
  sharedTypes = import ../../lib/infrastructure-types.nix { inherit lib; };

  connectionType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "NetworkManager connection ID used when matching profile secrets.";
      };
      profileName = mkOption {
        type = types.str;
        description = "Attribute name used for the declaratively managed NetworkManager profile.";
      };
      uuid = mkOption {
        type = types.strMatching "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}";
        description = "Stable NetworkManager connection UUID.";
      };
      interfaceName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Stable interface name, when the connection type requires one.";
      };
    };
  };

  profileConnections =
    (map (profile: profile.connection) (builtins.attrValues cfg.host.network.wifi))
    ++ (map (profile: profile.connection) (builtins.attrValues cfg.host.network.wireguard));
  unique = values: builtins.length values == builtins.length (lib.unique values);
in
{
  options.infrastructure = {
    host = {
      hostId = mkOption {
        type = types.nullOr (types.strMatching "[0-9a-fA-F]{8}");
        default = null;
        description = "Stable ZFS host identifier, required only by hosts composing a ZFS capability.";
      };
      system = mkOption {
        type = types.str;
        description = "Nix system identifier used to evaluate this host.";
      };
      timeZone = mkOption {
        type = types.str;
        description = "IANA time zone used by this host.";
      };
      network = {
        wifi = mkOption {
          default = { };
          description = "Wi-Fi profiles managed declaratively by NetworkManager.";
          type = types.attrsOf (
            types.submodule {
              options = {
                connection = mkOption {
                  type = connectionType;
                  description = "NetworkManager identity for this Wi-Fi profile.";
                };
                ssid = mkOption {
                  type = types.str;
                  description = "Wi-Fi network SSID.";
                };
                secretName = mkOption {
                  type = types.str;
                  description = "sops-nix secret containing the Wi-Fi passphrase.";
                };
                security = mkOption {
                  type = types.enum [
                    "sae"
                    "wpa-psk"
                  ];
                  description = "NetworkManager key management mode for this Wi-Fi network.";
                };
              };
            }
          );
        };
        wireguard = mkOption {
          default = { };
          description = "WireGuard profiles managed declaratively by NetworkManager.";
          type = types.attrsOf (
            types.submodule {
              options = {
                connection = mkOption {
                  type = connectionType;
                  description = "NetworkManager identity for this WireGuard profile.";
                };
                endpoint = mkOption {
                  type = types.str;
                  description = "WireGuard peer endpoint in host:port form.";
                };
                publicKey = mkOption {
                  type = types.str;
                  description = "Public key of the WireGuard peer.";
                };
                privateKeySecretName = mkOption {
                  type = types.str;
                  description = "sops-nix secret containing the local WireGuard private key.";
                };
                presharedKeySecretName = mkOption {
                  type = types.str;
                  description = "sops-nix secret containing the WireGuard preshared key.";
                };
                dns = mkOption {
                  type = types.str;
                  description = "DNS server used while this profile is active.";
                };
                addresses = mkOption {
                  type = types.listOf types.str;
                  description = "Local IPv4 and optional IPv6 interface addresses in CIDR notation.";
                };
              };
            }
          );
        };
      };
    };

    user = sharedTypes.userOptions;

    network.hosts = sharedTypes.networkHostsOption;
  };

  config.assertions = [
    {
      assertion = unique (map (connection: connection.id) profileConnections);
      message = "NetworkManager connection IDs must be unique.";
    }
    {
      assertion = unique (map (connection: connection.profileName) profileConnections);
      message = "NetworkManager profile names must be unique.";
    }
    {
      assertion = unique (map (connection: connection.uuid) profileConnections);
      message = "NetworkManager profile UUIDs must be unique.";
    }
    {
      assertion = unique (
        lib.filter (name: name != null) (map (connection: connection.interfaceName) profileConnections)
      );
      message = "NetworkManager interface names must be unique.";
    }
    {
      assertion = unique (map (profile: profile.secretName) (builtins.attrValues cfg.host.network.wifi));
      message = "Wi-Fi secret names must be unique.";
    }
  ]
  ++ lib.mapAttrsToList (_: profile: {
    assertion =
      builtins.length (lib.filter (address: !lib.hasInfix ":" address) profile.addresses) == 1
      && builtins.length (lib.filter (address: lib.hasInfix ":" address) profile.addresses) <= 1;
    message = "Each WireGuard profile must have exactly one IPv4 address and at most one IPv6 address.";
  }) cfg.host.network.wireguard;
}
