{
  inputs,
  pkgs,
  ...
}:
{
  home = {
    file = {
      ".hushlogin".text = "";
    };

    sessionVariables = {
      MANPAGER = "nvim +Man! -";
      PAGER = "less";
      SOPS_AGE_KEY_FILE = "$HOME/.config/sops/age/keys.txt";
    };

    packages = with pkgs; [
      shellcheck
      sops
      unzip
    ];
  };

  programs = {
    codex = {
      enable = true;
      settings = {
        approvals_reviewer = "auto_review";
        projects = {
          "/home/kyleh/nixos".trust_level = "trusted";
          "/home/kyleh/Projects/nixos".trust_level = "trusted";
        };
      };
    };

    dircolors = {
      enable = true;
      enableBashIntegration = true;
      extraConfig = builtins.readFile (inputs.dircolors-solarized + "/dircolors.256dark");
    };

    fd.enable = true;
    fzf.enable = true;
    gcc.enable = true;
    gh.enable = true;
    github-copilot-cli.enable = true;
    jq.enable = true;
    lazygit.enable = true;
    less.enable = true;
    ripgrep.enable = true;

    starship = {
      enable = true;
      enableBashIntegration = true;
      presets = [ "nerd-font-symbols" ];
      settings = {
        add_newline = false;
        format = "$username$hostname$directory$git_branch$git_status$character";
        username = {
          format = "[$user]($style)";
          show_always = true;
          style_user = "blue bold";
        };
        hostname = {
          format = "[@$hostname]($style) ";
          ssh_only = false;
          style = "blue bold";
        };
        directory = {
          format = "[$path]($style) ";
          style = "cyan bold";
          truncation_length = 3;
        };
        git_branch = {
          format = "[$symbol$branch]($style) ";
          style = "green bold";
        };
        git_status = {
          format = "[$all_status$ahead_behind]($style) ";
          style = "yellow bold";
        };
        character = {
          error_symbol = "[❯](red bold) ";
          success_symbol = "[❯](green bold) ";
        };
      };
    };

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
