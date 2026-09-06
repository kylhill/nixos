{ lib, ... }:
{
  imports = [
    ../modules/home/kyleh
    ../modules/home/kyleh/development.nix
    ../modules/home/kyleh/docker-tools.nix
    ../modules/home/kyleh/tmux.nix
  ];

  programs = {
    bash.profileExtra = lib.mkAfter ''
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

      if [[ $- == *i* ]] \
        && command -v tmux >/dev/null 2>&1 \
        && [[ -z "''${TMUX:-}" ]] \
        && [[ "''${TERM:-}" != dumb ]]; then
        exec tmux attach-session -t 0 >/dev/null
      fi
    '';

    tmux.newSession = true;
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
