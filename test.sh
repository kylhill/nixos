#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sandbox=false
offline=false
flake_ref=.
mode=
homes=()
dev_systems=()
usage() {
    echo 'usage: ./test.sh [--sandbox] [--offline] [--path] [--lint | --full | --home NAME ... --dev SYSTEM ...]'
    echo '  default/--full  lint, evaluate all flake outputs and standalone homes (no host build)'
    echo '  --lint          source checks only; no host, home, or development output evaluation'
    echo '  --home NAME     lint and evaluate a selected home activation derivation; repeatable'
    echo '  --dev SYSTEM    lint and evaluate all development shells for a system; repeatable'
    echo '  --sandbox       direct linters and daemon-backed Nix; local store requires explicit opt-in'
    echo '  --offline       use cached inputs/tools only; never retry online automatically'
    echo '  --path          include untracked files outside sandbox mode'
}
die() { echo "$*" >&2; exit 2; }
while (($#)); do
    case "$1" in
        --sandbox) sandbox=true ;;
        --offline) offline=true ;;
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
    nix_cmd=("$repo_dir/scripts/nix-sandbox")
fi
if "$offline"; then nix_cmd+=(--offline); fi

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
shell_files=(apply.sh test.sh update.sh scripts/nix-sandbox tests/test-runner.sh tests/fixtures/validation-tool)
run_stage 'Worktree whitespace' git diff --check || :
run_stage 'Staged whitespace' git diff --cached --check || :
for script in "${shell_files[@]}"; do
    run_stage "Shell syntax: $script" bash -n "$script" || :
done

if "$sandbox"; then
    # Reuse pinned executable paths by lock hash/architecture. If no cached
    # executable exists, PATH tools need neither Nix evaluation nor a store.
    sandbox_nix_root="${NIX_SANDBOX_ROOT:-${TMPDIR:-/tmp}/nixos-codex-nix-${UID}}"
    lock_hash=$(sha256sum flake.lock)
    tool_cache="$sandbox_nix_root/cache/validation-tools-${lock_hash%% *}-$(uname -m)"
    declare -A tool_paths=()
    if [[ -r $tool_cache ]]; then
        while read -r name tool_path; do
            case "$name" in
                nixfmt|statix|deadnix|shellcheck) tool_paths["$name"]=$tool_path ;;
            esac
        done < "$tool_cache"
    fi
    need_resolution=false
    for tool in nixfmt statix deadnix shellcheck; do
        tool_path=${tool_paths[$tool]:-}
        if [[ -z $tool_path || ! -x $tool_path/bin/$tool ]] && ! command -v "$tool" >/dev/null 2>&1; then
            need_resolution=true
        fi
    done
    # Resolve missing pinned tools together, without realizing them.
    export VALIDATION_FLAKE="path:$repo_dir"
    # Nix interpolation must reach the evaluator literally.
    # shellcheck disable=SC2016
    tools_expression='let pkgs = (builtins.getFlake (builtins.getEnv "VALIDATION_FLAKE")).inputs.nixpkgs.legacyPackages.${builtins.currentSystem}; in builtins.concatStringsSep "\n" (map (name: "${name} ${pkgs.${name}.outPath}") [ "nixfmt" "statix" "deadnix" "shellcheck" ])'
    if "$need_resolution"; then
        started=$SECONDS
        if resolved=$("${nix_cmd[@]}" eval --impure --raw --expr "$tools_expression" --no-update-lock-file); then
            while read -r name tool_path; do tool_paths["$name"]=$tool_path; done <<< "$resolved"
            # Cache failure must not prevent tools that are already runnable.
            if install -d -m 0700 "$sandbox_nix_root/cache" && cache_tmp=$(mktemp "$tool_cache.XXXXXX"); then
                if printf '%s\n' "$resolved" > "$cache_tmp"; then
                    mv -- "$cache_tmp" "$tool_cache" || rm -f -- "$cache_tmp"
                else
                    rm -f -- "$cache_tmp"
                fi
            fi
        else
            echo 'Pinned tools could not be resolved; trying available PATH tools.' >&2
        fi
        printf 'Tool resolution: %ss\n' "$((SECONDS - started))"
    fi
    for tool in nixfmt statix deadnix shellcheck; do
        tool_path=${tool_paths[$tool]:-}
        if [[ -n $tool_path && -x $tool_path/bin/$tool ]]; then
            runner=("$tool_path/bin/$tool")
        elif command -v "$tool" >/dev/null 2>&1; then
            echo "Pinned $tool unavailable; using PATH: $(command -v "$tool")"
            runner=("$tool")
        elif [[ -n $tool_path ]]; then
            expression="(builtins.getFlake (builtins.getEnv \"VALIDATION_FLAKE\")).inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}.$tool"
            runner=("${nix_cmd[@]}" shell --max-jobs 0 --builders '' --no-update-lock-file --impure --expr "$expression" --command "$tool")
        else
            echo "Cannot run $tool: no resolved pinned path or PATH executable." >&2
            failed=1
            continue
        fi
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
    if "$offline"; then
        echo 'Offline mode: if inputs/tools are missing, rerun the same scope without --offline once network access is available.' >&2
    fi
    echo "Validation incomplete or failed (scope: $mode). No full build or activation ran." >&2
    exit 1
fi
printf '\nSelected checks passed (scope: %s). No full build or activation ran.\n' "$mode"
