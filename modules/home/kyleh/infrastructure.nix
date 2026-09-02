{ lib, ... }:
let
  inherit (lib) mkOption types;
  sharedTypes = import ../../../lib/infrastructure-types.nix { inherit lib; };
in
{
  options.infrastructure = {
    user = sharedTypes.userOptions;
    network.hosts = sharedTypes.networkHostsOption;
    sources.dircolorsSolarized = mkOption {
      type = types.path;
      description = "Pinned dircolors-solarized source tree.";
    };
  };
}
