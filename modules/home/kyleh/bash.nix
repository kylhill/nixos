{
  inputs,
  pkgs,
  ...
}:
{
  home = {
    file = {
      ".dircolors".source = inputs.dircolors-solarized + "/dircolors.256dark";
      ".oh-my-bash".source = inputs.oh-my-bash;
      ".hushlogin".text = "";
    };

    sessionPath = [ "$HOME/.local/bin" ];
    sessionVariables = {
      PAGER = "less";
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    };

    packages = with pkgs; [
      ansible
      ansible-lint
      codex
      fd
      fzf
      gcc
      gh
      github-copilot-cli
      gnupg
      jq
      lazygit
      less
      ripgrep
      shellcheck
      sops
      universal-ctags
      unzip
    ];
  };

  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
      enableVteIntegration = true;
      historyControl = [
        "ignoreboth"
        "erasedups"
      ];
      historyFileSize = 20000;
      historySize = 10000;

      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../../";
        cls = "clear";
        l = "ls -CFh --color=auto";
        la = "ls -Ah --color=auto";
        ll = "ls -alFh --color=auto";
        ls = "ls --color=auto -h";
        grep = "grep --color=auto";
        fgrep = "grep -F --color=auto";
        egrep = "grep -E --color=auto";
        vim = "nvim";
        vimdiff = "nvim -d";
      };

      initExtra = ''
        export OSH="$HOME/.oh-my-bash"
        term_colors=0
        if command -v tput >/dev/null 2>&1; then
          term_colors=$(tput colors 2>/dev/null || printf 0)
        fi
        if [[ "''${TERM:-}" != linux && "$term_colors" =~ ^[0-9]+$ && "$term_colors" -ge 256 ]]; then
          OSH_THEME="agnoster"
        else
          OSH_THEME="font"
        fi
        unset term_colors
        DISABLE_AUTO_UPDATE="true"
        DISABLE_AUTO_TITLE="true"
        DISABLE_UNTRACKED_FILES_DIRTY="true"
        OMB_TERM_USE_TPUT=no
        completions=(docker ssh)
        aliases=()
        plugins=(git sudo)

        if [[ -r "$OSH/oh-my-bash.sh" ]]; then
          source "$OSH/oh-my-bash.sh"
        fi

        alias ls='ls --color=auto -h'
        alias grep='grep --color=auto'
        alias fgrep='grep -F --color=auto'
        alias egrep='grep -E --color=auto'
        alias ll='ls -alFh --color=auto'
        alias la='ls -Ah --color=auto'
        alias l='ls -CFh --color=auto'

        export HISTTIMEFORMAT="%F %T "
        export EDITOR="nvim"
        export VISUAL="nvim"
        export MANPAGER="nvim +Man! -"

        if [[ -t 1 ]]; then
          stty -ixon 2>/dev/null || true
        fi

        complete -d cd

        dbash() {
          command -v docker >/dev/null 2>&1 || {
            echo "docker not found" >&2
            return 127
          }
          [[ -n "''${1:-}" ]] || {
            echo "usage: dbash <container>" >&2
            return 2
          }
          local shell
          shell=$(docker exec "$1" sh -c 'command -v bash || command -v sh' 2>/dev/null) || {
            echo "container not found or no shell" >&2
            return 1
          }
          docker exec -it "$1" "$shell"
        }
        alias dsh=dbash

        dtail() {
          docker logs -tf --tail=150 "$@"
        }

        if [[ -n "''${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/ssh-agent.socket" ]]; then
          export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
        fi

        if [[ -t 0 ]]; then
          GPG_TTY=$(tty)
          export GPG_TTY
        fi
      '';
    };

    readline = {
      enable = true;
      bindings = {
        "\\e[A" = "history-search-backward";
        "\\e[B" = "history-search-forward";
      };
      variables = {
        bell-style = "none";
        colored-completion-prefix = true;
        colored-stats = true;
        completion-ignore-case = true;
        completion-map-case = true;
        mark-symlinked-directories = true;
        menu-complete-display-prefix = true;
        show-all-if-ambiguous = true;
        show-all-if-unmodified = true;
        skip-completed-text = true;
      };
    };

    gpg.enable = true;
  };

  services.gpg-agent = {
    enable = true;
    enableBashIntegration = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };
}
