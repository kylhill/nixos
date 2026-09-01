{
  config,
  lib,
  ...
}:
let
  wifiProfiles = config.infrastructure.host.network.wifi;

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
      key-mgmt = "sae";
      psk-flags = 1;
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
in
{
  networking.networkmanager.ensureProfiles = {
    profiles = lib.mapAttrs' (
      _: wifi: lib.nameValuePair wifi.connection.profileName (mkWifiProfile wifi)
    ) wifiProfiles;

    secrets.entries = lib.mapAttrsToList (_: wifi: {
      matchId = wifi.connection.id;
      matchType = "wifi";
      matchSetting = "802-11-wireless-security";
      key = "psk";
      file = config.sops.secrets.${wifi.secretName}.path;
    }) wifiProfiles;
  };
}
