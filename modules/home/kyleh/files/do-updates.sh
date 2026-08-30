#!/usr/bin/env bash
set -euo pipefail

infra_dir="${INFRA_DIR:-$HOME/infra}"
playbook="${PLAYBOOK:-site.yml}"
tags="${TAGS:-update}"
limit="${LIMIT:-}"
diff=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -l, --limit HOSTS       Limit to hosts
  -t, --tags TAGS         Only run tagged tasks (default: $tags)
  -D, --diff              Show diffs
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -l | --limit)
        [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || {
            usage >&2
            exit 2
        }
        limit="$2"
        shift 2
        ;;
    -t | --tags)
        [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || {
            usage >&2
            exit 2
        }
        tags="$2"
        shift 2
        ;;
    -D | --diff)
        diff=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 2
        ;;
    esac
done

[[ -d "$infra_dir" && -f "$infra_dir/$playbook" ]] || {
    echo "infra playbook not found: $infra_dir/$playbook" >&2
    exit 1
}

args=("$playbook" -t "$tags")
[[ "$diff" -eq 1 ]] && args+=(--diff)
[[ -n "$limit" ]] && args+=(-l "$limit")

cd "$infra_dir"
printf 'Running:' >&2
printf ' %q' ansible-playbook "${args[@]}" >&2
printf '\n' >&2
exec ansible-playbook "${args[@]}"
