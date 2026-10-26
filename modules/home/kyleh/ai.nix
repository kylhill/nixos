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

  mcpGrafana = pkgs.writeShellApplication {
    name = "mcp-grafana";
    runtimeInputs = [
      unstablePkgs.mcp-grafana
      pkgs.sops
    ];
    text = ''
      GRAFANA_SERVICE_ACCOUNT_TOKEN=$(sops --decrypt \
        --extract '["grafana"]["service-account-token"]' \
        "${config.home.homeDirectory}/infra/secrets/mcp-grafana.yaml")
      export GRAFANA_SERVICE_ACCOUNT_TOKEN
      export GRAFANA_URL="https://stats.tacomafia.net"
      exec mcp-grafana --disable-write "$@"
    '';
  };
in
{
  home.file.".config/codex/packages/standalone/current/codex" = {
    source = "${codexPackage}/bin/codex";
    force = true;
  };

  home.packages = [
    mcpGrafana
    # Stable keeps FastMCP on the compatible MCP 1 dependency set.
    pkgs.mcp-nixos
  ];

  programs = {
    codex = {
      enable = true;
      package = codexPackage;
    };
    github-copilot-cli = {
      enable = true;
      package = unstablePkgs.github-copilot-cli;
    };
  };
}
