{ lib, ... }:
{
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/development.nix
    ../modules/home/kyleh/docker-tools.nix
    ../modules/home/kyleh/tmux.nix
  ];

  targets.genericLinux = {
    enable = true;
  };

  programs = {
    bash.profileExtra = lib.mkAfter ''
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

      if [[ $- == *i* ]] \
        && [[ -z "''${TMUX:-}" ]] \
        && [[ "''${TERM:-}" != dumb ]]; then
        exec tmux new-session -A -s 0
      fi
    '';

    nixvim.waylandSupport = false;
  };

  services.ssh-agent = {
    enable = true;
    socket = "ssh-agent.socket";
  };

  systemd.user.sessionVariables = {
    SSH_AUTH_SOCK = "%t/ssh-agent.socket";
  };
}
