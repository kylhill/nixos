{ config, lib, ... }:
let
  inventory = import ../../lib/inventory.nix;
  wg = inventory.network.wireguard;

  ipv4Address = addresses: lib.findFirst (address: !(lib.hasInfix ":" address)) null addresses;
  ipv6Address = addresses: lib.findFirst (address: lib.hasInfix ":" address) null addresses;

  mkWireGuardProfile =
    {
      interfaceName,
      name,
      uuid,
      profile,
    }:
    {
      connection = {
        id = name;
        inherit uuid;
        type = "wireguard";
        interface-name = interfaceName;
        autoconnect = false;
        permissions = "";
      };

      wireguard = {
        private-key = "$WIREGUARD_PRIVATE_KEY";
        peer-routes = true;
      };

      "wireguard-peer.${profile.publicKey}" = {
        endpoint = profile.endpoint;
        preshared-key = "$WIREGUARD_PRESHARED_KEY";
        persistent-keepalive = 25;
        allowed-ips = "0.0.0.0/0;::/0;";
      };

      ipv4 = {
        method = "manual";
        address1 = ipv4Address profile.pang14Addresses;
        dns = "${profile.dns};";
      };

      ipv6 = {
        method = "manual";
        address1 = ipv6Address profile.pang14Addresses;
      };
    };
in
{
  config = lib.mkIf config.tacomafia.secrets.enable {
    sops.templates."networkmanager-wireguard.env" = {
      content = ''
        WIREGUARD_PRIVATE_KEY=${config.sops.placeholder."wireguard/private-key"}
        WIREGUARD_PRESHARED_KEY=${config.sops.placeholder."wireguard/preshared-key"}
      '';
      mode = "0400";
      restartUnits = [ "NetworkManager-ensure-profiles.service" ];
    };

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [ config.sops.templates."networkmanager-wireguard.env".path ];
      profiles = {
        wg-home = mkWireGuardProfile {
          interfaceName = "wg-home";
          name = "Home VPN";
          uuid = "40896239-b793-49b6-9f20-ee12ca3f374b";
          profile = wg.gateway;
        };
        wg-oci = mkWireGuardProfile {
          interfaceName = "wg-oci";
          name = "OCI VPN";
          uuid = "289ad1ab-7ac6-4a68-aff5-8d07a007d7c1";
          profile = wg.oci;
        };
      };
    };

    systemd.services.NetworkManager-ensure-profiles = {
      after = [ "sops-install-secrets.service" ];
      requires = [ "sops-install-secrets.service" ];
    };
  };
}
