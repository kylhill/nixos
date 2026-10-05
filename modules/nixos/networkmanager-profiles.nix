{
  config,
  hostNetwork,
  lib,
  ...
}:
lib.mkMerge (
  lib.mapAttrsToList (name: network: {
    sops.secrets = lib.genAttrs (lib.unique (builtins.attrValues network.secrets)) (_: {
      mode = "0400";
      restartUnits = [ "NetworkManager-ensure-profiles.service" ];
    });

    sops.templates."networkmanager-${name}.env" = {
      content =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            variable: secret: "${variable}=${config.sops.placeholder.${secret}}"
          ) network.secrets
        )
        + "\n";
      mode = "0400";
    };

    networking.networkmanager = {
      enable = true;
      ensureProfiles = {
        inherit (network) profiles;
        environmentFiles = [ config.sops.templates."networkmanager-${name}.env".path ];
      };
    };
  }) hostNetwork
)
