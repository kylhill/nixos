{ config, ... }:
{
  # Ansible owns the private client profile and its credentials.
  home.sessionVariables = {
    PGSERVICEFILE = "${config.home.homeDirectory}/.config/infra-db/pg_service.conf";
    PGSERVICE = "infra_operator";
  };
}
