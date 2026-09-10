{ config, ... }:
{
  sops.secrets.syncoid-pang14-to-syntax = {
    owner = "syncoid";
    group = "syncoid";
    mode = "0400";
  };

  programs.ssh.knownHosts.syntax = {
    extraHostNames = [ "syntax.l.tacomafia.net" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOGj7CYXzcrApGOmFdo/bxIbcunYIOjZ8pjjSvw9/S4x";
  };

  services.sanoid = {
    enable = true;
    interval = "*-*-* *:00:00";

    templates.standard = {
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 3;
      yearly = 0;
      autosnap = true;
      autoprune = true;
    };

    datasets."rpool/home".use_template = [ "standard" ];
  };

  services.syncoid = {
    enable = true;
    interval = "*-*-* *:15:00";
    sshKey = config.sops.secrets.syncoid-pang14-to-syntax.path;
    commonArgs = [
      "--no-sync-snap"
      "--create-bookmark"
    ];

    commands."rpool/home" = {
      target = "syncoid@syntax.l.tacomafia.net:srv/backup/device/pang14/home";
      recvOptions = "u";
      service = {
        requires = [ "sanoid.service" ];
        after = [ "sanoid.service" ];
      };
    };

    service = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
    };
  };

  systemd = {
    # Wait for snapshots to finish before replication, including timer catch-up.
    services.sanoid.serviceConfig.Type = "oneshot";

    timers = {
      sanoid.timerConfig.Persistent = true;
      syncoid-rpool-home.timerConfig.Persistent = true;
    };
  };
}
