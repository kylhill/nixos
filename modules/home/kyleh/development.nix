let
  colors = import ./solarized.nix;
in
{
  imports = [ ./neovim.nix ];

  programs = {
    bat = {
      enable = true;
      config.theme = "Solarized (dark)";
    };
    fd.enable = true;
    fzf = {
      enable = true;
      colors = {
        bg = colors.base03;
        "bg+" = colors.base02;
        fg = colors.base0;
        "fg+" = colors.base1;
        hl = colors.yellow;
        "hl+" = colors.yellow;
        border = colors.base01;
        info = colors.blue;
        prompt = colors.green;
        pointer = colors.magenta;
        marker = colors.cyan;
        spinner = colors.yellow;
        header = colors.blue;
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
    ripgrep.enable = true;

    direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
      silent = true;
    };
  };
}
