{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  home.packages = [
    pkgs.mcp-grafana
  ];

  programs = {
    codex.enableMcpIntegration = true;
    github-copilot-cli.enableMcpIntegration = true;

    mcp = {
      enable = true;
      servers = {
        grafana = {
          command = "${pkgs.mcp-grafana}/bin/mcp-grafana";
          env = {
            GRAFANA_SERVICE_ACCOUNT_TOKEN.file = config.sops.secrets."grafana/service-account-token".path;
            GRAFANA_URL = "https://stats.tacomafia.net";
          };
        };
        nixos.command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
      };
    };
  };

  sops = {
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
    defaultSopsFile = ../../../secrets/home.yaml;
    secrets."grafana/service-account-token" = { };
  };
}
