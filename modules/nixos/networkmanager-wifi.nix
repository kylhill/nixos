{
  config,
  inventory,
  lib,
  pkgs,
  ...
}:
let
  wifi = inventory.network.wifi.tacomafiaLan;
  environmentFile = "/run/networkmanager-profile-secrets/wifi.env";

  prepareEnvironment = pkgs.writeShellApplication {
    name = "prepare-networkmanager-wifi-environment";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      password=$(< ${lib.escapeShellArg config.sops.secrets.${wifi.secretName}.path})
      temporary=$(mktemp /run/networkmanager-profile-secrets/wifi.env.XXXXXX)
      trap 'rm -f "$temporary"' EXIT

      # ensureProfiles sources its environment files as shell input. %q keeps
      # every valid WPA passphrase character literal during that step.
      printf 'TACOMAFIA_LAN_PASSWORD=%q\n' "$password" > "$temporary"
      chmod 0600 "$temporary"
      mv -f "$temporary" ${lib.escapeShellArg environmentFile}
      trap - EXIT
    '';
  };
in
{
  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ environmentFile ];
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
        psk = "$TACOMAFIA_LAN_PASSWORD";
      };

      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  systemd.services = {
    prepare-networkmanager-wifi-environment = {
      description = "Safely encode the Wi-Fi secret for NetworkManager profile generation";
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
      before = [ "NetworkManager-ensure-profiles.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "networkmanager-profile-secrets";
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = lib.getExe prepareEnvironment;
      };
    };

    NetworkManager-ensure-profiles = {
      after = [ "prepare-networkmanager-wifi-environment.service" ];
      requires = [ "prepare-networkmanager-wifi-environment.service" ];
    };
  };
}
