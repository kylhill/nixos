#!/usr/bin/env bash
set -euo pipefail

dry_run=0
if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=1
    shift
fi

share_root="${1:-}"
[[ -n "$share_root" && -d "$share_root" ]] || {
    echo "usage: $0 [--dry-run] /path/to/samba/share" >&2
    exit 2
}

find_args=(
    -iname '*.exe' -o
    -iname '*.bat' -o
    -iname '*.msi' -o
    -iname '*.ps1' -o
    -iname '*.reg'
)

if [[ "$dry_run" -eq 1 ]]; then
    find "$share_root" -type f \( "${find_args[@]}" \) -print
else
    find "$share_root" -type f \( "${find_args[@]}" \) -print0 |
        while IFS= read -r -d '' file; do
            chmod a+x -- "$file"
            printf 'chmod a+x %q\n' "$file"
        done
fi
