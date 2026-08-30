{ ... }:
{
  home.file.".cache/ssh/.keep".text = "";

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = builtins.readFile ./files/ssh.conf;
  };

  services.ssh-agent = {
    enable = true;
    socket = "ssh-agent.socket";
  };
}
