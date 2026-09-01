{
  user = {
    name = "kyleh";
    uid = 1000;
    fullName = "Kyle Hill";
    email = "kylhill@gmail.com";
    homeDirectory = "/home/kyleh";
    gitSigningKey = "E644A61F810BDC4D1294867A2E37EF3EA077FAD8";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3B/FlRNV435YERy7hUtp/RW6v2uX9KF0dm+y7WTuy9 Kyle's Key - 7/25/2020";
  };

  network = {
    wifi.tacomafiaLan = {
      ssid = "tacomafia_LAN";
      uuid = "a9830c88-7236-4ee1-8ffa-2302b6f604af";
    };

    wireguard = {
      gateway = {
        endpoint = "wg.tacomafia.net:53410";
        publicKey = "gmRcLomamblci8EdapO7mOQH+TvxnUshcTBrEKPztX0=";
        dns = "192.168.6.1";
        pang14Addresses = [
          "192.168.6.8/24"
          "fd06:4f9a:934d:6::8/64"
        ];
      };

      oci = {
        endpoint = "wg-oci.tacomafia.net:53411";
        publicKey = "JA16G3T33+e/2MlJfDkKp2AcDLEY+CCrR8mVrxrvdW4=";
        dns = "10.60.60.1";
        pang14Addresses = [
          "10.60.60.5/24"
          "fd60:60ed:4bbc::5/64"
        ];
      };
    };
  };
}
