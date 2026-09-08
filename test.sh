#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sandbox=false
flake_ref=.
mode=
homes=()
dev_systems=()
usage() {
    echo 'usage: ./test.sh [--sandbox] [--path] [--lint | --full | --home NAME ... --dev SYSTEM ...]'
    echo '  default/--full  lint, evaluate all flake outputs and standalone homes (no host build)'
    echo '  --lint          source checks only; no host, home, or development output evaluation'
    echo '  --home NAME     lint and evaluate a selected home activation derivation; repeatable'
    echo '  --dev SYSTEM    lint and evaluate all development shells for a system; repeatable'
    echo '  --sandbox       direct PATH linters and evaluation including untracked files'
    echo '  --path          include untracked files outside sandbox mode'
}
die() { echo "$*" >&2; exit 2; }
while (($#)); do
    case "$1" in
        --sandbox) sandbox=true ;;
        --path) flake_ref=path:. ;;
        --lint|--full)
            [[ -z $mode || $mode == "${1#--}" ]] || die 'Do not combine --lint/--full with another scope.'
            mode=${1#--}
            ;;
        --home|--dev)
            [[ $# -ge 2 && $2 =~ ^[a-zA-Z0-9_-]+$ ]] || die "$1 requires a name containing letters, digits, underscores or hyphens."
            [[ -z $mode || $mode == selected ]] || die 'Do not combine --lint/--full with selected outputs.'
            mode=selected
            if [[ $1 == --home ]]; then homes+=("$2"); else dev_systems+=("$2"); fi
            shift
            ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
    shift
done
mode=${mode:-full}
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
cd "$repo_dir"
nix_cmd=(nix)
if "$sandbox"; then
    flake_ref=path:.
fi

failed=0
run_stage() {
    local description=$1 started=$SECONDS status=0
    shift
    printf '\n==> %s\n' "$description"
    "$@" || status=$?
    printf '==> %s: exit %s (%ss)\n' "$description" "$status" "$((SECONDS - started))"
    if ((status)); then failed=1; fi
    return "$status"
}
printf 'Validation scope: %s; homes: %s; dev systems: %s\n' "$mode" "${homes[*]:-none}" "${dev_systems[*]:-none}"
shell_files=(apply.sh test.sh update.sh tests/test-runner.sh tests/fixtures/validation-tool)
run_stage 'Worktree whitespace' git diff --check || :
run_stage 'Staged whitespace' git diff --cached --check || :
for script in "${shell_files[@]}"; do
    run_stage "Shell syntax: $script" bash -n "$script" || :
done

if "$sandbox"; then
    for tool in nixfmt statix deadnix shellcheck; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "Cannot run $tool: expected on PATH from the default development shell." >&2
            failed=1
            continue
        fi
        runner=("$tool")
        case "$tool" in
            nixfmt)
                mapfile -d '' -t nix_files < <(git ls-files --cached --others --exclude-standard -z -- '*.nix')
                args=(--check "${nix_files[@]}")
                ;;
            statix) args=(check .) ;;
            deadnix) args=(--fail .) ;;
            shellcheck) args=("${shell_files[@]}") ;;
        esac
        run_stage "Lint: $tool" "${runner[@]}" "${args[@]}" || :
    done
else
    if system=$("${nix_cmd[@]}" eval --impure --raw --expr builtins.currentSystem); then
        for check in formatting statix deadnix shellcheck; do
            run_stage "Lint: $check" "${nix_cmd[@]}" build --no-link --no-update-lock-file \
                "$flake_ref#checks.$system.$check" || :
        done
    else
        failed=1
    fi
fi

# Keep collecting independent failures, but do not spend time evaluating outputs
# after source checks fail.
if ((failed == 0)); then
    if [[ $mode == full ]]; then
        run_stage 'Full flake evaluation (no builds)' "${nix_cmd[@]}" flake check "$flake_ref" \
            --no-build --all-systems --no-update-lock-file || :
        run_stage 'All standalone home activation derivations' "${nix_cmd[@]}" eval \
            "$flake_ref#homeConfigurations" --no-update-lock-file --json \
            --apply 'homes: builtins.mapAttrs (_: home: home.activationPackage.drvPath) homes' || :
    else
        for home in "${homes[@]}"; do
            run_stage "Home: $home activation derivation" "${nix_cmd[@]}" eval \
                "$flake_ref#homeConfigurations.$home.activationPackage.drvPath" --json --no-update-lock-file || :
        done
        for system in "${dev_systems[@]}"; do
            run_stage "Development shells: $system" "${nix_cmd[@]}" eval \
                "$flake_ref#devShells.$system" --json --no-update-lock-file \
                --apply 'shells: builtins.mapAttrs (_: shell: shell.drvPath) shells' || :
        done
    fi
else
    echo 'Source checks incomplete or failed; output evaluation skipped.' >&2
fi
if ((failed)); then
    echo "Validation incomplete or failed (scope: $mode). No full build or activation ran." >&2
    exit 1
fi
printf '\nSelected checks passed (scope: %s). No full build or activation ran.\n' "$mode"
