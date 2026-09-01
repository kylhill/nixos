{ config, lib, ... }:
let
  inventory = import ../../lib/inventory.nix;
  wifi = inventory.network.wifi.tacomafiaLan;
in
{
  config = lib.mkIf config.tacomafia.secrets.enable {
    sops.templates."networkmanager-wifi.env" = {
      content = ''
        TACOMAFIA_LAN_PASSWORD=${config.sops.placeholder."wifi/tacomafia-lan-password"}
      '';
      mode = "0400";
      restartUnits = [ "NetworkManager-ensure-profiles.service" ];
    };

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.sops.templates."networkmanager-wifi.env".path ];
      profiles.tacomafia_LAN = {
        connection = {
          id = wifi.ssid;
          inherit (wifi) uuid;
          type = "wifi";
          autoconnect = true;
          permissions = "";
        };

        wifi = {
          mode = "infrastructure";
          ssid = wifi.ssid;
        };

        wifi-security = {
          key-mgmt = "sae";
          psk = "$TACOMAFIA_LAN_PASSWORD";
        };

        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };

    systemd.services.NetworkManager-ensure-profiles = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };
  };
}
