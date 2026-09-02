{ config, lib, ... }:
{
  assertions = [
    {
      assertion = config.infrastructure.host.hostId != null;
      message = "The ZFS root capability requires infrastructure.host.hostId.";
    }
  ];

  networking.hostId = lib.mkIf (
    config.infrastructure.host.hostId != null
  ) config.infrastructure.host.hostId;

  boot.supportedFilesystems = [ "zfs" ];
}
