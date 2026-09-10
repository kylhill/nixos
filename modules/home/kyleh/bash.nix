{
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
  };

  programs = {
    less.enable = true;

    dircolors = {
      enable = true;
      extraConfig = builtins.readFile "${pkgs.dircolors-solarized}/256dark.no-bold";
    };

    starship = {
      enable = true;
      enableBashIntegration = true;
      presets = [ "nerd-font-symbols" ];
      settings = {
        add_newline = false;
        format = "$username$hostname$directory$nix_shell$git_branch$git_status$character";
        username = {
          format = "[$user]($style)";
          show_always = true;
          style_user = "blue";
        };
        hostname = {
          format = "[@$hostname]($style) ";
          ssh_only = false;
          style = "blue";
        };
        directory = {
          format = "[$path]($style) ";
          style = "cyan";
          truncation_length = 3;
        };
        nix_shell = {
          format = "[$symbol]($style) ";
          style = "cyan";
          symbol = " ";
        };
        git_branch = {
          format = "[$symbol$branch]($style) ";
          style = "green";
        };
        git_status = {
          format = "[$all_status$ahead_behind]($style) ";
          style = "yellow";
        };
        character = {
          error_symbol = "[❯](red)";
          success_symbol = "[❯](green)";
        };
      };
    };

    bash = {
      enable = true;
      historyControl = [
        "ignoreboth"
        "erasedups"
      ];

      shellOptions = [
        "histappend"
        "extglob"
        "globstar"
        "checkjobs"
        "cdspell"
        "dirspell"
        "lithist"
      ];

      shellAliases = {
        l = "ls -CFh --color=auto";
        la = "ls -Ah --color=auto";
        ll = "ls -alFh --color=auto";
        ls = "ls --color=auto -h";
        grep = "grep --color=auto";
      };

      initExtra = ''
        if [[ -t 0 ]]; then
          ${pkgs.coreutils}/bin/stty -ixon 2>/dev/null || true
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
        history-preserve-point = true;
        mark-symlinked-directories = true;
        menu-complete-display-prefix = true;
        show-all-if-ambiguous = true;
        show-all-if-unmodified = true;
        skip-completed-text = true;
      };
    };
  };
}
