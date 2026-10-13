{
  programs = {
    bat = {
      enable = true;
      config.theme = "Solarized (dark)";
    };
    fd.enable = true;
    fzf = {
      enable = true;
      colors = {
        bg = "#002b36";
        "bg+" = "#073642";
        fg = "#839496";
        "fg+" = "#93a1a1";
        hl = "#b58900";
        "hl+" = "#b58900";
        border = "#586e75";
        info = "#268bd2";
        prompt = "#859900";
        pointer = "#d33682";
        marker = "#2aa198";
        spinner = "#b58900";
        header = "#268bd2";
      };
      defaultCommand = "fd --type f --hidden --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
      fileWidgetOptions = [
        "--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
      ];
      tmux = {
        enableShellIntegration = true;
        shellIntegrationOptions = [ "-p 80%,60%" ];
      };
    };
    gh.enable = true;
    ripgrep.enable = true;

    direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
      silent = true;
    };
  };
}
