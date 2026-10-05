{ config, ... }:
{
  assertions = [
    {
      assertion = config.networking.hostId != null;
      message = "The ZFS root capability requires networking.hostId.";
    }
  ];

  boot.supportedFilesystems = [ "zfs" ];
}
