_: {
  programs.lazydocker.enable = true;

  programs.bash = {
    shellAliases.dsh = "dbash";

    initExtra = ''
      dbash() {
        command -v docker >/dev/null 2>&1 || {
          echo "docker not found" >&2
          return 127
        }
        [[ -n "''${1:-}" ]] || {
          echo "usage: dbash <container>" >&2
          return 2
        }

        local shell
        shell=$(docker exec "$1" sh -c 'command -v bash || command -v sh' 2>/dev/null) || {
          echo "container not found or no shell" >&2
          return 1
        }

        docker exec -it "$1" "$shell"
      }

      dtail() {
        docker logs -tf --tail="150" "$@"
      }

      _complete_docker_containers() {
        local cur="''${COMP_WORDS[COMP_CWORD]}"
        local containers
        local container
        containers=$(docker ps --format '{{.Names}}' 2>/dev/null)
        COMPREPLY=()
        while IFS= read -r container; do
          COMPREPLY+=("$container")
        done < <(compgen -W "$containers" -- "$cur")
      }
      complete -F _complete_docker_containers dbash dsh dtail

      dprune() {
        local exclude="''${1:-minecraft}"
        echo "Pruning Docker resources (excluding: $exclude)..."

        docker ps -a --filter status=exited --filter status=created --format '{{.Names}}' |
          grep -Fv -- "$exclude" |
          xargs -r docker rm

        docker image prune -a -f

        docker network ls --format '{{.Name}}' --filter type=custom |
          grep -Fv -- "$exclude" |
          xargs -r docker network rm 2>/dev/null || true

        docker volume prune -f
        docker builder prune -f
      }
    '';
  };
}
