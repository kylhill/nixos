{ config, lib, ... }:
let
  # Ansible owns the private client profile and its credentials.
  profile = lib.escapeShellArg "${config.home.homeDirectory}/.config/infra-db/mariadb.cnf";
in
{
  programs.bash.shellAliases = {
    mysql = "mysql --defaults-file=${profile}";
    mariadb = "mariadb --defaults-file=${profile}";
  };
}
