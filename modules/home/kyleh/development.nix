{
  programs = {
    bat = {
      enable = true;
      config.theme = "Solarized (dark)";
    };
    fd.enable = true;
    fzf = {
      enable = true;
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
