let
  userName = "kyleh";
in
{
  sharedUnfreePackages = [
    "github-copilot-cli"
    "vscode"
  ];

  hosts = {
    pang14 = {
      hostId = "ab5f3534";
      system = "x86_64-linux";
      timeZone = "America/Chicago";
      # Native NetworkManager profiles; secrets map environment variables to sops names.
      network = {
        wifi = {
          profiles = {
            tacomafia_LAN = {
              connection = {
                autoconnect = true;
                id = "tacomafia_LAN";
                permissions = "";
                type = "wifi";
                uuid = "a9830c88-7236-4ee1-8ffa-2302b6f604af";
              };
              ipv4 = {
                method = "auto";
              };
              ipv6 = {
                method = "auto";
              };
              wifi = {
                mode = "infrastructure";
                powersave = 3;
                ssid = "tacomafia_LAN";
              };
              wifi-security = {
                key-mgmt = "sae";
                psk = "$WIFI_PSK_TACOMAFIA_LAN";
                psk-flags = 0;
              };
            };
          };
          secrets = {
            WIFI_PSK_TACOMAFIA_LAN = "wifi/tacomafia-lan-password";
          };
        };
        wireguard = {
          profiles = {
            wg-home = {
              connection = {
                autoconnect = false;
                id = "Home VPN";
                interface-name = "wg-home";
                permissions = "";
                type = "wireguard";
                uuid = "40896239-b793-49b6-9f20-ee12ca3f374b";
              };
              ipv4 = {
                address1 = "192.168.6.8/24";
                dns = "192.168.6.1;";
                method = "manual";
              };
              ipv6 = {
                address1 = "fd06:4f9a:934d:6::8/64";
                method = "manual";
              };
              wireguard = {
                peer-routes = true;
                private-key = "$WIREGUARD_PRIVATE_KEY";
                private-key-flags = 0;
              };
              "wireguard-peer.gmRcLomamblci8EdapO7mOQH+TvxnUshcTBrEKPztX0=" = {
                allowed-ips = "0.0.0.0/0;::/0;";
                endpoint = "wg.tacomafia.net:53410";
                persistent-keepalive = 25;
                preshared-key = "$WIREGUARD_PRESHARED_KEY";
                preshared-key-flags = 0;
              };
            };
            wg-oci = {
              connection = {
                autoconnect = false;
                id = "OCI VPN";
                interface-name = "wg-oci";
                permissions = "";
                type = "wireguard";
                uuid = "289ad1ab-7ac6-4a68-aff5-8d07a007d7c1";
              };
              ipv4 = {
                address1 = "10.60.60.5/24";
                dns = "10.60.60.1;";
                method = "manual";
              };
              ipv6 = {
                address1 = "fd60:60ed:4bbc::5/64";
                method = "manual";
              };
              wireguard = {
                peer-routes = true;
                private-key = "$WIREGUARD_PRIVATE_KEY";
                private-key-flags = 0;
              };
              "wireguard-peer.JA16G3T33+e/2MlJfDkKp2AcDLEY+CCrR8mVrxrvdW4=" = {
                allowed-ips = "0.0.0.0/0;::/0;";
                endpoint = "wg-oci.tacomafia.net:53411";
                persistent-keepalive = 25;
                preshared-key = "$WIREGUARD_PRESHARED_KEY";
                preshared-key-flags = 0;
              };
            };
          };
          secrets = {
            WIREGUARD_PRIVATE_KEY = "wireguard/private-key";
            WIREGUARD_PRESHARED_KEY = "wireguard/preshared-key";
          };
        };
      };
    };
  };

  user = {
    name = userName;
    uid = 1000;
    fullName = "Kyle Hill";
    email = "kylhill@gmail.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3B/FlRNV435YERy7hUtp/RW6v2uX9KF0dm+y7WTuy9 Kyle's Key - 7/25/2020";
  };

  network = {
    hosts = {
      syntax.fqdn = "syntax.tacomafia.net";
      gateway.fqdn = "gateway.l.tacomafia.net";
      oci.fqdn = "oci.vpn.tacomafia.net";
      git = {
        fqdn = "git.tacomafia.net";
        port = 2222;
      };
    };
  };
}
