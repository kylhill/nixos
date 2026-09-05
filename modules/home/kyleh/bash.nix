{
  config,
  pkgs,
  ...
}:
{
  home = {
    file = {
      ".hushlogin".text = "";
    };

    sessionVariables = {
      PAGER = "less";
    };

    packages = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
  };

  programs = {
    command-not-found.enable = false;

    less.enable = true;
    nix-index.enable = true;

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
      historyControl = [
        "ignoreboth"
        "erasedups"
      ];
      historyFileSize = 20000;
      historySize = 10000;

      shellAliases = {
        ".." = "cd ..";
        "..." = "cd ../../";
        l = "ls -CFh --color=auto";
        la = "ls -Ah --color=auto";
        ll = "ls -alFh --color=auto";
        ls = "ls --color=auto -h";
        grep = "grep --color=auto";
        dsh = "dbash";
      };

      initExtra = ''
        eval "$(${pkgs.coreutils}/bin/dircolors --sh ${config.xdg.configHome}/dir_colors)"

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

        dtail() {
          docker logs -tf --tail="150" "$@"
        }

        _complete_docker_containers() {
          local cur="''${COMP_WORDS[COMP_CWORD]}"
          local containers
          local container
          containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
          COMPREPLY=()
          while IFS= read -r container; do
            COMPREPLY+=("$container")
          done < <(compgen -W "$containers" -- "$cur")
        }
        complete -F _complete_docker_containers dbash dsh dtail

        dprune() {
          local exclude="''${1:-minecraft}"
          echo "Pruning Docker resources (excluding: $exclude)..."

          docker ps -a --filter status=exited --filter status=created --format '{{.Names}}' |
            grep -Fv -- "$exclude" |
            xargs -r docker rm

          docker image prune -a -f

          docker network ls --format '{{.Name}}' --filter type=custom |
            grep -Fv -- "$exclude" |
            xargs -r docker network rm 2>/dev/null || true

          docker volume prune -f
          docker builder prune -f
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
  };

  xdg.configFile.dir_colors.source = "${pkgs.dircolors-solarized}/256dark";
}
