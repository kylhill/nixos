_: {
  disko.devices = {
    disk.pang14 = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B97472";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            size = "40G";
            content = {
              type = "swap";
              discardPolicy = "both";
            };
          };

          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool.rpool = {
      type = "zpool";
      options = {
        ashift = "12";
        cachefile = "none";
        autotrim = "off";
      };
      rootFsOptions = {
        acltype = "posixacl";
        atime = "off";
        compression = "zstd";
        dnodesize = "auto";
        mountpoint = "none";
        normalization = "formD";
        xattr = "sa";
      };
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options = {
            mountpoint = "legacy";
          };
        };

        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options = {
            mountpoint = "legacy";
          };
        };

        home = {
          type = "zfs_fs";
          mountpoint = "/home";
          options = {
            mountpoint = "legacy";
          };
        };

        var = {
          type = "zfs_fs";
          mountpoint = "/var";
          options = {
            mountpoint = "legacy";
          };
        };
      };
    };
  };
}
