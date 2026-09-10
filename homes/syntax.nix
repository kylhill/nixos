{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ../modules/home/kyleh
    ../modules/home/kyleh/development.nix
    ../modules/home/kyleh/docker-tools.nix
    ../modules/home/kyleh/tmux.nix
    ../modules/home/kyleh/ubuntu.nix
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

  sops = {
    defaultSopsFile = ../secrets/home.yaml;
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    secrets = {
      "ssh/private-key" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
        mode = "0600";
      };
      "ssh/public-key" = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519.pub";
        mode = "0644";
      };
      "ssh/ubnt-20220508/private-key" = {
        sopsFile = ../secrets/syntax.yaml;
        path = "${config.home.homeDirectory}/.ssh/ubnt-20220508";
        mode = "0600";
      };
      "ssh/ubnt-20220508/public-key" = {
        sopsFile = ../secrets/syntax.yaml;
        path = "${config.home.homeDirectory}/.ssh/ubnt-20220508.pub";
        mode = "0644";
      };
    };
  };

  systemd.user.sessionVariables.SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent.socket";
}
