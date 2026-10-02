{
  config,
  pkgs,
  ...
}:
let
  systemBubblewrap = pkgs.writeShellScriptBin "bwrap" ''
    exec /usr/bin/bwrap "$@"
  '';

  codexPackage =
    if config.targets.genericLinux.enable then
      # Bypass nixpkgs' PATH wrapper so Ubuntu's bwrap takes precedence.
      (pkgs.writeShellApplication {
        name = "codex";
        runtimeInputs = [ systemBubblewrap ];
        text = ''
          exec ${pkgs.codex}/bin/.codex-wrapped "$@"
        '';
      }).overrideAttrs
        (_: {
          version = pkgs.codex.version;
        })
    else
      pkgs.codex;

  mcpGrafana = pkgs.writeShellApplication {
    name = "mcp-grafana";
    runtimeInputs = [
      pkgs.mcp-grafana
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
    pkgs.mcp-nixos
  ];

  programs = {
    codex = {
      enable = true;
      package = codexPackage;
    };
    github-copilot-cli = {
      enable = true;
      package = pkgs.github-copilot-cli;
    };
  };
}
