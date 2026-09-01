{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.infrastructure;

  connectionType = types.submodule {
    options = {
      id = mkOption { type = types.str; };
      profileName = mkOption { type = types.str; };
      uuid = mkOption {
        type = types.strMatching "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}";
      };
      interfaceName = mkOption {
        type = types.nullOr types.str;
        default = null;
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
      hardwareModules = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      hostId = mkOption {
        type = types.strMatching "[0-9a-fA-F]{8}";
        description = "Stable ZFS host identifier.";
      };
      system = mkOption { type = types.str; };
      timeZone = mkOption { type = types.str; };
      network = {
        wifi = mkOption {
          default = { };
          type = types.attrsOf (
            types.submodule {
              options = {
                connection = mkOption { type = connectionType; };
                ssid = mkOption { type = types.str; };
                secretName = mkOption { type = types.str; };
              };
            }
          );
        };
        wireguard = mkOption {
          default = { };
          type = types.attrsOf (
            types.submodule {
              options = {
                connection = mkOption { type = connectionType; };
                endpoint = mkOption { type = types.str; };
                publicKey = mkOption { type = types.str; };
                dns = mkOption { type = types.str; };
                addresses = mkOption {
                  type = types.listOf types.str;
                };
              };
            }
          );
        };
      };
    };

    user = {
      name = mkOption { type = types.str; };
      uid = mkOption { type = types.ints.positive; };
      fullName = mkOption { type = types.str; };
      email = mkOption { type = types.str; };
      homeDirectory = mkOption { type = types.str; };
      sshDirectory = mkOption { type = types.str; };
      sshPublicKey = mkOption { type = types.str; };
    };

    network.hosts = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            fqdn = mkOption { type = types.str; };
            port = mkOption {
              type = types.nullOr types.port;
              default = null;
            };
          };
        }
      );
    };
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
