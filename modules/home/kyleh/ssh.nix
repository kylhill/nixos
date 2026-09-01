{ inventory, lib, ... }:
let
  hosts = inventory.network.hosts;
  identityFile = "${inventory.user.sshDirectory}/id_ed25519";
in
{
  systemd.user.tmpfiles.rules = [ "d %h/.cache/ssh 0700 - - -" ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      syntax.HostName = hosts.syntax.fqdn;
      gateway.HostName = hosts.gateway.fqdn;
      oci.HostName = hosts.oci.fqdn;

      "htpc htpc? kvm wap wap? sw-16".HostName = "%h.l.tacomafia.net";

      trusted = lib.hm.dag.entryBefore [ "root-hosts" ] {
        header = "Host syntax ${hosts.syntax.fqdn} syntax.l.tacomafia.net gateway gateway.tacomafia.net ${hosts.gateway.fqdn} gateway.*.tacomafia.net oci oci.tacomafia.net ${hosts.oci.fqdn} 192.168.1.30 192.168.?.1 192.168.6.6";
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
        IdentityFile = identityFile;
        IdentitiesOnly = true;
        User = "git";
      };

      ${hosts.git.fqdn} = {
        IdentityFile = identityFile;
        IdentitiesOnly = true;
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        Port = hosts.git.port;
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
        IdentityFile = identityFile;
        ServerAliveCountMax = 3;
        ServerAliveInterval = 60;
        User = inventory.user.name;
      };
    };
  };
}
