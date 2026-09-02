{
  config,
  lib,
  ...
}:
let
  wifiProfiles = config.infrastructure.host.network.wifi;
  unique = values: builtins.length values == builtins.length (lib.unique values);

  mkWifiProfile = wifi: {
    connection = {
      inherit (wifi.connection) id uuid;
      type = "wifi";
      autoconnect = true;
      permissions = "";
    };

    wifi = {
      mode = "infrastructure";
      inherit (wifi) ssid;
      powersave = 3;
    };

    wifi-security = {
      key-mgmt = wifi.security;
      psk-flags = 1;
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
in
{
  options.infrastructure.host.network.wifi = lib.mkOption {
    default = { };
    description = "Wi-Fi profiles managed declaratively by NetworkManager.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          connection = lib.mkOption {
            description = "NetworkManager identity for this Wi-Fi profile.";
            type = lib.types.submodule {
              options = {
                id = lib.mkOption {
                  type = lib.types.str;
                  description = "NetworkManager connection ID used when matching profile secrets.";
                };
                uuid = lib.mkOption {
                  type = lib.types.strMatching "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}";
                  description = "Stable NetworkManager connection UUID.";
                };
              };
            };
          };
          ssid = lib.mkOption {
            type = lib.types.str;
            description = "Wi-Fi network SSID.";
          };
          secretName = lib.mkOption {
            type = lib.types.str;
            description = "sops-nix secret containing the Wi-Fi passphrase.";
          };
          security = lib.mkOption {
            type = lib.types.enum [
              "sae"
              "wpa-psk"
            ];
            description = "NetworkManager key management mode for this Wi-Fi network.";
          };
        };
      }
    );
  };

  config = {
    assertions = [
      {
        assertion = unique (map (profile: profile.connection.id) (builtins.attrValues wifiProfiles));
        message = "NetworkManager Wi-Fi connection IDs must be unique.";
      }
      {
        assertion = unique (map (profile: profile.connection.uuid) (builtins.attrValues wifiProfiles));
        message = "NetworkManager Wi-Fi profile UUIDs must be unique.";
      }
      {
        assertion = unique (map (profile: profile.secretName) (builtins.attrValues wifiProfiles));
        message = "Wi-Fi secret names must be unique.";
      }
    ];

    sops.secrets = lib.mapAttrs' (
      _: wifi:
      lib.nameValuePair wifi.secretName {
        mode = "0400";
        restartUnits = [ "nm-file-secret-agent.service" ];
      }
    ) wifiProfiles;

    networking.networkmanager = {
      enable = true;
      ensureProfiles = {
        profiles = lib.mapAttrs (_: mkWifiProfile) wifiProfiles;

        secrets.entries = lib.mapAttrsToList (_: wifi: {
          matchId = wifi.connection.id;
          matchType = "wifi";
          matchSetting = "802-11-wireless-security";
          key = "psk";
          file = config.sops.secrets.${wifi.secretName}.path;
        }) wifiProfiles;
      };
    };
  };
}
