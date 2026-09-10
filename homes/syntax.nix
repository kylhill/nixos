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
      # Force use of local ssh-agent
      export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
      unset SSH_AGENT_PID

      if [[ $- == *i* ]] \
        && [[ -z "''${TMUX:-}" ]] \
        && [[ "''${TERM:-}" != dumb ]]; then
        exec tmux new-session -A -s 0
      fi
    '';

    tmux.extraConfig = lib.mkAfter ''
      set-environment -gu SSH_AGENT_PID
      set-environment -g SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
      set-hook -g client-attached 'set-environment SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"; set-environment -u SSH_AGENT_PID'
      set-hook -g after-new-session 'set-environment SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"; set-environment -u SSH_AGENT_PID'
    '';

    nixvim.waylandSupport = false;
  };

  services.ssh-agent = {
    enable = true;
    socket = "ssh-agent.socket";
  };

  systemd.user.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent.socket";
}
