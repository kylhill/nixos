{
  latestPkgs,
  pkgs,
  ...
}:
{
  imports = [
    ./neovim-development.nix
  ];

  home = {
    packages = [
      pkgs.socat
    ];
  };

  programs = {
    codex = {
      enable = true;
      package = latestPkgs.codex;
    };
    direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
    };
    gh.enable = true;
    github-copilot-cli = {
      enable = true;
      package = latestPkgs.github-copilot-cli;
    };
  };
}
