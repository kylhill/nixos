{ lib, ... }:
let
  sharedTypes = import ../../../lib/infrastructure-types.nix { inherit lib; };
in
{
  options.infrastructure = {
    user = sharedTypes.userOptions;
    network.hosts = sharedTypes.networkHostsOption;
  };
}
