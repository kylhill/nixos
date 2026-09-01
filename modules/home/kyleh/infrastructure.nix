{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.infrastructure = {
    user = {
      name = mkOption { type = types.str; };
      uid = mkOption { type = types.ints.positive; };
      fullName = mkOption { type = types.str; };
      email = mkOption { type = types.str; };
      homeDirectory = mkOption { type = types.str; };
      sshDirectory = mkOption { type = types.str; };
      sshPublicKey = mkOption { type = types.str; };
    };
    network.hosts = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            fqdn = mkOption { type = types.str; };
            port = mkOption {
              type = types.nullOr types.port;
              default = null;
            };
          };
        }
      );
    };
    sources.dircolorsSolarized = mkOption { type = types.path; };
  };
}
