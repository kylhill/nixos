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
      key-mgmt = wifi.security;
      psk-flags = 1;
    };

    ipv4.method = "auto";
    ipv6.method = "auto";
  };
in
{
  sops.secrets = lib.mapAttrs' (
    _: wifi:
    lib.nameValuePair wifi.secretName {
      mode = "0400";
      restartUnits = [ "nm-file-secret-agent.service" ];
    }
  ) wifiProfiles;

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
