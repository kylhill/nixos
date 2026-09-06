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
    less.enable = true;

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
        l = "ls -CFh --color=auto";
        la = "ls -Ah --color=auto";
        ll = "ls -alFh --color=auto";
        ls = "ls --color=auto -h";
        grep = "grep --color=auto";
      };

      initExtra = ''
        eval "$(${pkgs.coreutils}/bin/dircolors --sh ${config.xdg.configHome}/dir_colors)"

        if [[ -t 1 ]]; then
          stty -ixon 2>/dev/null || true
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
  };

  xdg.configFile.dir_colors.source = "${pkgs.dircolors-solarized}/256dark";
}
