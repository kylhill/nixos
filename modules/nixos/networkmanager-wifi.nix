{
  config,
  host,
  ...
}:
let
  wifi = host.network.wifi.tacomafiaLan;
in
{
  networking.networkmanager.ensureProfiles = {
    profiles.${wifi.connection.profileName} = {
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

    secrets.entries = [
      {
        matchId = wifi.connection.id;
        matchType = "wifi";
        matchSetting = "802-11-wireless-security";
        key = "psk";
        file = config.sops.secrets.${wifi.secretName}.path;
      }
    ];
  };
}
