{ pkgs, ... }:
{
  _module.args.wslAgent = true;

  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/development.nix
    ../modules/home/kyleh/ubuntu-headless.nix
  ];

  home.packages = [
    pkgs.wsl2-ssh-agent
  ];

  home.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/wsl2-ssh-agent.sock";
  systemd.user.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/wsl2-ssh-agent.sock";
  systemd.user.services.wsl2-ssh-agent = {
    Unit.Description = "Bridge the Windows OpenSSH agent into WSL";
    Service = {
      ExecStart = "${pkgs.wsl2-ssh-agent}/bin/wsl2-ssh-agent -foreground -socket=%t/wsl2-ssh-agent.sock";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
