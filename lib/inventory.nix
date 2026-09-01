let
  userName = "kyleh";
  homeDirectory = "/home/${userName}";
in
{
  hosts = {
    pang14 = {
      hostId = "ab5f3534";
      system = "x86_64-linux";
      timeZone = "America/Chicago";
    };
  };

  user = {
    name = userName;
    uid = 1000;
    fullName = "Kyle Hill";
    email = "kylhill@gmail.com";
    inherit homeDirectory;
    sshDirectory = "${homeDirectory}/.ssh";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3B/FlRNV435YERy7hUtp/RW6v2uX9KF0dm+y7WTuy9 Kyle's Key - 7/25/2020";
  };

  network = {
    wifi.tacomafiaLan = {
      connection = {
        id = "tacomafia_LAN";
        profileName = "tacomafia_LAN";
        uuid = "a9830c88-7236-4ee1-8ffa-2302b6f604af";
      };
      ssid = "tacomafia_LAN";
      secretName = "wifi/tacomafia-lan-password";
    };

    wireguard = {
      gateway = {
        connection = {
          id = "Home VPN";
          interfaceName = "wg-home";
          profileName = "wg-home";
          uuid = "40896239-b793-49b6-9f20-ee12ca3f374b";
        };
        endpoint = "wg.tacomafia.net:53410";
        publicKey = "gmRcLomamblci8EdapO7mOQH+TvxnUshcTBrEKPztX0=";
        dns = "192.168.6.1";
        addresses = [
          "192.168.6.8/24"
          "fd06:4f9a:934d:6::8/64"
        ];
      };

      oci = {
        connection = {
          id = "OCI VPN";
          interfaceName = "wg-oci";
          profileName = "wg-oci";
          uuid = "289ad1ab-7ac6-4a68-aff5-8d07a007d7c1";
        };
        endpoint = "wg-oci.tacomafia.net:53411";
        publicKey = "JA16G3T33+e/2MlJfDkKp2AcDLEY+CCrR8mVrxrvdW4=";
        dns = "10.60.60.1";
        addresses = [
          "10.60.60.5/24"
          "fd60:60ed:4bbc::5/64"
        ];
      };
    };

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
