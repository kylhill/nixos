{ lib }:
let
  inherit (lib) mkOption types;
in
{
  userOptions = {
    name = mkOption {
      type = types.str;
      description = "Login name of the primary managed user.";
    };
    uid = mkOption {
      type = types.ints.positive;
      description = "Stable numeric UID of the primary managed user.";
    };
    fullName = mkOption {
      type = types.str;
      description = "Display name of the primary managed user.";
    };
    email = mkOption {
      type = types.str;
      description = "Email address used by user-scoped tools such as Git.";
    };
    homeDirectory = mkOption {
      type = types.str;
      description = "Absolute home directory of the primary managed user.";
    };
    sshDirectory = mkOption {
      type = types.str;
      description = "Absolute directory containing the user's SSH identities.";
    };
    sshPublicKey = mkOption {
      type = types.str;
      description = "Public key authorized for login as the primary managed user.";
    };
  };

  networkHostsOption = mkOption {
    description = "Stable names and connection details for managed network hosts.";
    type = types.attrsOf (
      types.submodule {
        options = {
          fqdn = mkOption {
            type = types.str;
            description = "Fully qualified domain name of the host.";
          };
          port = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Non-default service port, or null to use the protocol default.";
          };
        };
      }
    );
  };
}
