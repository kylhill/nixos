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
      pkgs.runCommand latestPkgs.codex.name { } ''
        cp -a ${latestPkgs.codex} $out
        chmod -R u+w $out
        old_bwrap=${latestPkgs.bubblewrap}
        new_bwrap=${systemBubblewrap}
        test "''${#old_bwrap}" -eq "''${#new_bwrap}"
        grep -aFq "$old_bwrap" $out/bin/codex
        ${pkgs.gnused}/bin/sed -i "s|$old_bwrap|$new_bwrap|g" $out/bin/codex
        grep -aFq "$new_bwrap" $out/bin/codex
      ''
    else
      latestPkgs.codex;

  mcpGrafana = pkgs.writeShellApplication {
    name = "mcp-grafana";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.mcp-grafana
      pkgs.sops
    ];
    text = ''
      runtime_dir=$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/mcp-grafana.XXXXXX")
      token_file="$runtime_dir/token"
      trap 'rm -f "$token_file"; rmdir "$runtime_dir"' EXIT HUP INT TERM

      sops --decrypt \
        --extract '["grafana"]["service-account-token"]' \
        "${config.home.homeDirectory}/infra/secrets/mcp-grafana.yaml" > "$token_file"
      chmod 600 "$token_file"

      GRAFANA_SERVICE_ACCOUNT_TOKEN=$(cat "$token_file")
      export GRAFANA_SERVICE_ACCOUNT_TOKEN
      export GRAFANA_URL="https://stats.tacomafia.net"
      mcp-grafana --disable-write "$@"
    '';
  };
in
{
  home.file.".config/codex/packages/standalone/current/codex".source = "${codexPackage}/bin/codex";

  home.packages = [
    mcpGrafana
    pkgs.mcp-nixos
  ];

  programs = {
    fd.enable = true;
    ripgrep.enable = true;

    codex = {
      enable = true;
      package = codexPackage;
    };
    github-copilot-cli = {
      enable = true;
      package = latestPkgs.github-copilot-cli;
    };
  };
}
