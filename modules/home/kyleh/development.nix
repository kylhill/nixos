{
  config,
  latestPkgs,
  pkgs,
  ...
}:
{
  imports = [ ./neovim-development.nix ];

  home = {
    packages = [ pkgs.shellcheck ];
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
