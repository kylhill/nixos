{
  config,
  pkgs,
  unstablePkgs,
  ...
}:
let
  systemBubblewrap = pkgs.writeShellScriptBin "bwrap" ''
    exec /usr/bin/bwrap "$@"
  '';

  codexPackage =
    if config.targets.genericLinux.enable then
      # Keep Ubuntu's bwrap ahead of the packaged sandbox fallback.
      (pkgs.writeShellApplication {
        name = "codex";
        runtimeInputs = [ systemBubblewrap ];
        text = ''
          exec ${unstablePkgs.codex}/bin/codex "$@"
        '';
      }).overrideAttrs
        (_: {
          version = unstablePkgs.codex.version;
        })
    else
      unstablePkgs.codex;
in
{
  home.file.".config/codex/packages/standalone/current/codex" = {
    source = "${codexPackage}/bin/codex";
    force = true;
  };

  programs.codex = {
    enable = true;
    package = codexPackage;
  };

  systemd.user.services.codex-remote-control = {
    Unit.Description = "Codex remote control";
    Service = {
      Type = "simple";
      # Codex rejects group-writable temporary socket directories.
      UMask = "0077";
      ExecStart = "${codexPackage}/bin/codex remote-control --no-daemon";
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "CODEX_HOME=${config.home.sessionVariables.CODEX_HOME}"
        "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin"
      ];
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStopSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
