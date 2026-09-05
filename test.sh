#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sandbox=false
flake_ref=.
for arg in "$@"; do
    case "$arg" in
        --sandbox) sandbox=true ;;
        --path) flake_ref=path:. ;;
        --help|-h)
            echo 'usage: ./test.sh [--sandbox] [--path]'
            echo '  --sandbox  daemonless evaluation and direct linting; defaults to path:. for untracked files'
            echo '  --path     include untracked files in flake evaluation'
            exit 0
            ;;
        *) echo "Unknown argument: $arg" >&2; exit 2 ;;
    esac
done

export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
cd "$repo_dir"

run_stage() {
    local description=$1
    shift
    printf '\n==> %s\n' "$description"
    "$@"
}

shell_files=(apply.sh test.sh update.sh scripts/install-host-key scripts/install-preflight)
run_stage 'Checking worktree whitespace' git diff --check
run_stage 'Checking staged whitespace' git diff --cached --check
for script in "${shell_files[@]}"; do
    run_stage "Checking shell syntax: $script" bash -n "$script"
done

nix_args=()
if "$sandbox"; then
    flake_ref=path:.
    sandbox_nix_root="${TMPDIR:-/tmp}/nixos-codex-nix-${UID}"
    install -d -m 0700 "$sandbox_nix_root/store" "$sandbox_nix_root/cache"
    export XDG_CACHE_HOME="$sandbox_nix_root/cache"
    nix_args=(--store "$sandbox_nix_root/store")
fi

failed=0
if ! run_stage 'Evaluating flake outputs without building them' \
    nix flake check "$flake_ref" "${nix_args[@]}" --no-build --no-update-lock-file; then
    if ! "$sandbox"; then exit 1; fi
    failed=1
    echo 'Flake evaluation failed; continuing independent source checks.' >&2
fi

if ! "$sandbox"; then
    system=$(nix eval --impure --raw --expr builtins.currentSystem)
    for check in formatting statix deadnix shellcheck; do
        run_stage "Running the $check check" \
            nix build --no-link --no-update-lock-file "$flake_ref#checks.${system}.$check"
    done
else
    # Resolve pinned tools without asking the daemon or realizing a derivation.
    export VALIDATION_FLAKE="path:$repo_dir"
    for tool in nixfmt statix deadnix shellcheck; do
        expression="(builtins.getFlake (builtins.getEnv \"VALIDATION_FLAKE\")).inputs.nixpkgs.legacyPackages.\${builtins.currentSystem}.$tool"
        if ! tool_path=$(nix eval "${nix_args[@]}" --impure --raw --expr "$expression.outPath"); then
            echo "Cannot resolve pinned $tool" >&2
            failed=1
            continue
        fi
        if [[ -x "$tool_path/bin/$tool" ]]; then
            runner=("$tool_path/bin/$tool")
        elif command -v "$tool" >/dev/null 2>&1; then
            echo "Pinned $tool is unavailable; using PATH version: $(command -v "$tool")"
            runner=("$tool")
        else
            # Substitute tool binaries only. Never build source or use remote builders.
            # Nix may need mount permissions to execute from this relocated store.
            runner=(nix shell "${nix_args[@]}" --max-jobs 0 --builders '' --impure --expr "$expression" --command "$tool")
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
        if ! run_stage "Running $tool directly" "${runner[@]}" "${args[@]}"; then
            echo "$tool failed or could not run; see the error above." >&2
            failed=1
        fi
    done
    if ((failed)); then
        echo 'Validation incomplete or failed. No system build or activation was run.' >&2
        exit 1
    fi
fi

printf '\nAll development checks passed. No system build or activation was run.\n'
