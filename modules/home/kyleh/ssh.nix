{ lib, ... }:
{
  systemd.user.tmpfiles.rules = [ "d %h/.cache/ssh 0700 - - -" ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      syntax.HostName = "syntax.tacomafia.net";
      gateway.HostName = "gateway.l.tacomafia.net";
      oci.HostName = "oci.vpn.tacomafia.net";

      "htpc htpc? kvm wap wap? sw-16".HostName = "%h.l.tacomafia.net";

      trusted = lib.hm.dag.entryBefore [ "root-hosts" ] {
        header = "Host syntax syntax.tacomafia.net syntax.l.tacomafia.net gateway gateway.tacomafia.net gateway.*.tacomafia.net oci oci.tacomafia.net oci.vpn.tacomafia.net 192.168.1.30 192.168.?.1 192.168.6.6";
        AddKeysToAgent = "yes";
        ForwardAgent = true;
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        StrictHostKeyChecking = "accept-new";
        UpdateHostKeys = true;
      };

      root-hosts = {
        header = "Host htpc htpc.l.tacomafia.net htpc? htpc?.l.tacomafia.net kvm kvm.l.tacomafia.net";
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        StrictHostKeyChecking = "accept-new";
        User = "root";
      };

      network-devices = {
        header = "Host wap wap.l.tacomafia.net wap? wap?.l.tacomafia.net sw-16 sw-16.l.tacomafia.net";
        HostKeyAlgorithms = "+ssh-rsa";
        IdentityFile = "~/.ssh/ubnt-20220508";
        IdentitiesOnly = true;
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PubkeyAcceptedAlgorithms = "+ssh-rsa";
        StrictHostKeyChecking = "accept-new";
      };

      "github.com" = {
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
        User = "git";
      };

      "git.tacomafia.net" = {
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        Port = 2222;
        StrictHostKeyChecking = "accept-new";
        User = "git";
      };

      "*" = {
        ConnectTimeout = 10;
        ControlMaster = "auto";
        ControlPath = "~/.cache/ssh/%C.sock";
        ControlPersist = "10m";
        ForwardAgent = false;
        HashKnownHosts = true;
        IdentityFile = "~/.ssh/id_ed25519";
        ServerAliveCountMax = 3;
        ServerAliveInterval = 60;
        User = "kyleh";
      };
    };
  };

  services.ssh-agent = {
    enable = true;
    socket = "ssh-agent.socket";
  };
}
