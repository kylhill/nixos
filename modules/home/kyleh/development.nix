{
  config,
  latestPkgs,
  pkgs,
  ...
}:
let
  systemBubblewrap =
    (pkgs.writeShellScriptBin "bwrap" ''
      exec /usr/bin/bwrap "$@"
    '').overrideAttrs
      {
        name = latestPkgs.bubblewrap.name;
      };

  codexPackage =
    if config.targets.genericLinux.enable then
      pkgs.replaceDependency {
        drv = latestPkgs.codex;
        oldDependency = latestPkgs.bubblewrap;
        newDependency = systemBubblewrap;
      }
    else
      latestPkgs.codex;
in
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
      package = codexPackage;
    };
    direnv = {
      enable = true;
      config.global.hide_env_diff = true;
      nix-direnv.enable = true;
      silent = true;
    };
    gh.enable = true;
    github-copilot-cli = {
      enable = true;
      package = latestPkgs.github-copilot-cli;
    };
  };
}
