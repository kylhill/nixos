{ ... }:
{
  home.file.".cache/ssh/.keep".text = "";

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Home Manager 26.05 requires the default Host * block to be declared
    # whenever raw trailing configuration is supplied through extraConfig.
    # The actual defaults remain in files/ssh.conf so their OpenSSH ordering is
    # preserved during the initial dotfiles migration.
    settings."*" = { };
    extraConfig = builtins.readFile ./files/ssh.conf;
  };

  services.ssh-agent = {
    enable = true;
    socket = "ssh-agent.socket";
  };
}
