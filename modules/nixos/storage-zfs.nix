_: {
  boot = {
    supportedFilesystems = [ "zfs" ];

    kernelParams = [
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.zpool=zsmalloc"
      "zswap.max_pool_percent=20"
      "zswap.shrinker_enabled=1"
    ];

    zfs = {
      # This pool belongs exclusively to pang14. Permit recovery after an
      # unclean shutdown or an installer import under a different host ID.
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
