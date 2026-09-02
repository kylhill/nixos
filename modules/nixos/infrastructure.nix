{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.infrastructure = {
    host = {
      hostId = mkOption {
        type = types.nullOr (types.strMatching "[0-9a-fA-F]{8}");
        default = null;
        description = "Stable ZFS host identifier, required only by hosts composing a ZFS capability.";
      };
      timeZone = mkOption {
        type = types.str;
        description = "IANA time zone used by this host.";
      };
    };

    user = {
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
        default = "/home/${config.infrastructure.user.name}";
        description = "Absolute home directory of the primary managed user.";
      };
      sshDirectory = mkOption {
        type = types.str;
        default = "${config.infrastructure.user.homeDirectory}/.ssh";
        description = "Absolute directory containing the user's SSH identities.";
      };
      sshPublicKey = mkOption {
        type = types.str;
        description = "Public key authorized for login as the primary managed user.";
      };
    };

    network.hosts = mkOption {
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
  };
}
