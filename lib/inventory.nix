{
  domain = "tacomafia.net";

  user = {
    name = "kyleh";
    uid = 1000;
    fullName = "Kyle Hill";
    email = "kylhill@gmail.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3B/FlRNV435YERy7hUtp/RW6v2uX9KF0dm+y7WTuy9 Kyle's Key - 7/25/2020";
  };

  network = {
    lanV4 = "192.168.0.0/16";
    ula = "fd06:4f9a:934d::/48";
    dnsV4 = "192.168.1.30";

    wireguard = {
      gateway = {
        endpoint = "wg.tacomafia.net:53410";
        publicKey = "gmRcLomamblci8EdapO7mOQH+TvxnUshcTBrEKPztX0=";
        pang14Addresses = [
          "192.168.6.8/24"
          "fd06:4f9a:934d:6::8/64"
        ];
      };

      oci = {
        endpoint = "wg-oci.tacomafia.net:53411";
        publicKey = "JA16G3T33+e/2MlJfDkKp2AcDLEY+CCrR8mVrxrvdW4=";
        pang14Addresses = [
          "10.60.60.5/24"
          "fd60:60ed:4bbc::5/64"
        ];
      };

      pang14PublicKey = "aSwGLb+DVJhHVJVyCdvFE4R6vuLvpVxPZqaOFszoljg=";
    };
  };
}
