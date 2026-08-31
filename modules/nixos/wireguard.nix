{
  config,
  lib,
  pkgs,
  ...
}:
let
  inventory = import ../../lib/inventory.nix;
  wg = inventory.network.wireguard;
  privateKeyFile = config.sops.secrets."wireguard/private-key".path;
  presharedKeyFile = config.sops.secrets."wireguard/preshared-key".path;

  vpn = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.wireguard-tools
    ];
    text = ''
      usage() {
        echo "usage: vpn <home|oci> <up|down|status>" >&2
        exit 2
      }

      [[ $# -eq 2 ]] || usage
      profile="$1"
      action="$2"

      case "$profile" in
        home|oci) ;;
        *) usage ;;
      esac

      unit="wg-quick-wg-$profile.service"
      other="wg-quick-wg-$([[ "$profile" == home ]] && echo oci || echo home).service"

      case "$action" in
        up)
          sudo systemctl stop "$other"
          sudo systemctl start "$unit"
          ;;
        down)
          sudo systemctl stop "$unit"
          ;;
        status)
          systemctl --no-pager --full status "$unit"
          ;;
        *) usage ;;
      esac
    '';
  };
in
{
  config = lib.mkIf config.tacomafia.secrets.enable {
    networking.wg-quick.interfaces = {
      wg-home = {
        autostart = false;
        address = wg.gateway.pang14Addresses;
        dns = [ wg.gateway.dns ];
        privateKeyFile = privateKeyFile;
        peers = [
          {
            publicKey = wg.gateway.publicKey;
            presharedKeyFile = presharedKeyFile;
            endpoint = wg.gateway.endpoint;
            persistentKeepalive = 25;
            allowedIPs = [
              "0.0.0.0/0"
              "::/0"
            ];
          }
        ];
      };

      wg-oci = {
        autostart = false;
        address = wg.oci.pang14Addresses;
        dns = [ wg.oci.dns ];
        privateKeyFile = privateKeyFile;
        peers = [
          {
            publicKey = wg.oci.publicKey;
            presharedKeyFile = presharedKeyFile;
            endpoint = wg.oci.endpoint;
            persistentKeepalive = 25;
            allowedIPs = [
              "0.0.0.0/0"
              "::/0"
            ];
          }
        ];
      };
    };

    systemd.services = {
      wg-quick-wg-home.unitConfig.Conflicts = [ "wg-quick-wg-oci.service" ];
      wg-quick-wg-oci.unitConfig.Conflicts = [ "wg-quick-wg-home.service" ];
    };

    environment.systemPackages = [ vpn ];
  };
}
