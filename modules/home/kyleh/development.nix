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
      pkgs.bubblewrap
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
      nix-direnv.enable = true;
    };
    gh.enable = true;
    github-copilot-cli = {
      enable = true;
      package = latestPkgs.github-copilot-cli;
    };
  };
}
