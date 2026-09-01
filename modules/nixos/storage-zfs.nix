_: {
  boot = {
    supportedFilesystems = [ "zfs" ];

    # zswap is a compressed cache in front of the persistent resume swap.
    kernelParams = [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=zsmalloc"
      "zswap.max_pool_percent=20"
      "zswap.shrinker_enabled=1"
    ];

    zfs = {
      # rpool belongs exclusively to this laptop. Allow initrd to recover it
      # after an unclean shutdown or after it was last imported by an installer
      # environment with a different host ID.
      forceImportRoot = true;
      forceImportAll = false;
    };
  };

  services.zfs = {
    autoSnapshot = {
      enable = true;
      frequent = 0;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 3;
    };

    autoScrub = {
      enable = true;
      interval = "monthly";
    };

    trim = {
      enable = true;
      interval = "weekly";
    };
  };
}
