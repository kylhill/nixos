{
  config,
  latestPkgs,
  pkgs,
  ...
}:
{
  imports = [
    ./mcp.nix
    ./neovim-development.nix
  ];

  home = {
    packages = [
      pkgs.bubblewrap
      pkgs.shellcheck
      pkgs.socat
    ];
    sessionVariables = {
      SOPS_AGE_KEY_FILE = "${config.xdg.configHome}/sops/age/keys.txt";
    };
  };

  programs = {
    fd.enable = true;
    fzf.enable = true;
    jq.enable = true;
    ripgrep.enable = true;
    codex = {
      enable = true;
      package = latestPkgs.codex;
      settings = {
        model = "gpt-5.6-sol";
        model_reasoning_effort = "low";
        notice.hide_rate_limit_model_nudge = true;
        projects = {
          "/home/kyleh/Projects/nixos".trust_level = "trusted";
          "/home/kyleh/nixos".trust_level = "trusted";
        };
        tui = {
          status_line = [
            "model-with-reasoning"
            "current-dir"
            "five-hour-limit"
            "weekly-limit"
          ];
          status_line_use_colors = true;
          theme = "solarized-dark";
        };
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    gh = {
      enable = true;
      package = latestPkgs.gh;
    };
    github-copilot-cli = {
      enable = true;
      package = latestPkgs.github-copilot-cli;
    };
    lazygit = {
      enable = true;
      settings.gui.nerdFontsVersion = "3";
    };
  };
}
