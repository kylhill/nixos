#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sandbox=false
flake_ref=.
mode=
homes=()
integrated_hosts=()
integrated_users=()
dev_systems=()
system_hosts=()
fixtures=()
option_ref=
check_system=
usage() {
    echo 'usage: ./test.sh [--sandbox] [--path] SCOPE ...'
    echo '  An explicit scope is required; --lint, --full and --ci exclude selected outputs.'
    echo '  --ci            full validation plus all fixture suites'
    echo '  --fixtures SUITE lint and runner/apply/windows/all fixtures; repeatable and combinable'
    echo '  --system HOST   lint and evaluate system assertions, without a system build'
    echo '  --option-system HOST OPTION'
    echo '                  evaluate one non-secret NixOS config option, without lint'
    echo '  --full          lint, evaluate all flake outputs and standalone homes (no host build)'
    echo '  --lint          source checks only; no host, home, or development output evaluation'
    echo '  --home NAME     lint and evaluate a selected home activation derivation; repeatable'
    echo '  --integrated-home HOST USER'
    echo '                  lint and evaluate only an integrated home activation derivation'
    echo '  --dev SYSTEM    lint and evaluate all development shells for a system; repeatable'
    echo '  --option-home NAME OPTION'
    echo '                  evaluate one non-secret standalone home config option, without lint'
    echo '  --option-integrated-home HOST USER OPTION'
    echo '                  evaluate one non-secret integrated home config option, without lint'
    echo '  --home, --integrated-home, --system and --dev are repeatable and combinable.'
    echo '  --fixtures combines with lint, selected outputs or full evaluation; option scopes are exclusive.'
    echo '  --sandbox       direct PATH linters and evaluation including untracked files'
    echo '  --path          flag with no argument; selects path:. to include untracked files outside sandbox mode'
}
die() { echo "$*" >&2; exit 2; }
safe_attr() { [[ $1 =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; }
safe_option() { [[ $1 =~ ^[a-zA-Z_][a-zA-Z0-9_-]*(\.[a-zA-Z_][a-zA-Z0-9_-]*)*$ ]]; }
add_fixture() {
    local suite=$1 existing
    for existing in "${fixtures[@]}"; do
        [[ $existing != "$suite" ]] || return 0
    done
    fixtures+=("$suite")
}
while (($#)); do
    case "$1" in
        --sandbox) sandbox=true ;;
        --path) flake_ref=path:. ;;
        --lint|--full|--ci)
            [[ -z $mode || $mode == "${1#--}" ]] || die 'Do not combine --lint/--full/--ci with another scope.'
            mode=${1#--}
            ;;
        --fixtures)
            [[ $# -ge 2 ]] || die '--fixtures requires runner, apply, windows or all.'
            [[ $mode != option ]] || die 'An option check cannot be combined with fixtures.'
            case "$2" in
                runner|apply|windows) add_fixture "$2" ;;
                all) for suite in runner apply windows; do add_fixture "$suite"; done ;;
                *) die '--fixtures requires runner, apply, windows or all.' ;;
            esac
            shift
            ;;
        --home|--dev|--system)
            if [[ $# -lt 2 ]] || ! safe_attr "$2"; then
                die "$1 requires a safe attribute identifier (letter/underscore, then letters, digits, underscores or hyphens)."
            fi
            [[ -z $mode || $mode == selected ]] || die 'Do not combine --lint/--full with selected outputs.'
            mode=selected
            case "$1" in
                --home) homes+=("$2") ;;
                --dev) dev_systems+=("$2") ;;
                --system) system_hosts+=("$2") ;;
            esac
            shift
            ;;
        --integrated-home)
            if [[ $# -lt 3 ]] || ! safe_attr "$2" || ! safe_attr "$3"; then
                die '--integrated-home requires HOST USER, each a safe attribute identifier (letter/underscore, then letters, digits, underscores or hyphens).'
            fi
            [[ -z $mode || $mode == selected ]] || die 'Do not combine --lint/--full with selected outputs.'
            mode=selected
            integrated_hosts+=("$2")
            integrated_users+=("$3")
            shift 2
            ;;
        --option-home|--option-system)
            if [[ $# -lt 3 ]] || ! safe_attr "$2" || ! safe_option "$3"; then
                die "$1 requires NAME and a dotted OPTION path."
            fi
            [[ -z $mode ]] || die 'An option check cannot be combined with another scope.'
            mode=option
            if [[ $1 == --option-home ]]; then
                option_ref="homeConfigurations.$2.config.$3"
            else
                option_ref="nixosConfigurations.$2.config.$3"
            fi
            shift 2
            ;;
        --option-integrated-home)
            if [[ $# -lt 4 ]] || ! safe_attr "$2" || ! safe_attr "$3" || ! safe_option "$4"; then
                die '--option-integrated-home requires HOST, USER and a dotted OPTION path.'
            fi
            [[ -z $mode ]] || die 'An option check cannot be combined with another scope.'
            mode=option
            option_ref="nixosConfigurations.$2.config.home-manager.users.$3.$4"
            shift 3
            ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
    shift
done
if [[ -z $mode && ${#fixtures[@]} -gt 0 ]]; then mode=selected; fi
[[ -n $mode ]] || die 'An explicit scope is required. See --help.'
[[ $mode != option || ${#fixtures[@]} == 0 ]] || die 'An option check cannot be combined with fixtures.'
if [[ $mode == ci ]]; then
    for suite in runner apply windows; do add_fixture "$suite"; done
fi
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
cd "$repo_dir"
nix_cmd=(nix)
if "$sandbox"; then
    flake_ref=path:.
fi

if [[ $mode == option ]]; then
    exec "${nix_cmd[@]}" eval "$flake_ref#$option_ref" --json --no-update-lock-file
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
printf 'Validation scope: %s; homes: %s; systems: %s; dev systems: %s; fixtures: %s\n' \
    "$mode" "${homes[*]:-none}" "${system_hosts[*]:-none}" "${dev_systems[*]:-none}" "${fixtures[*]:-none}"
for i in "${!integrated_hosts[@]}"; do
    printf 'Integrated home: %s/%s\n' "${integrated_hosts[i]}" "${integrated_users[i]}"
done
mapfile -t shell_files < tests/shell-files
run_stage 'Worktree whitespace' git diff --check || :
run_stage 'Staged whitespace' git diff --cached --check || :
check_shell_syntax() {
    local script status=0
    for script in "${shell_files[@]}"; do
        bash -n "$script" || status=1
    done
    return "$status"
}
run_stage 'Shell syntax' check_shell_syntax || :

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
                args=(--check)
                for file in "${nix_files[@]}"; do
                    if [[ -e $file || -L $file ]]; then
                        args+=("$file")
                    fi
                done
                if ((${#args[@]} == 1)); then continue; fi
                ;;
            statix) args=(check .) ;;
            deadnix) args=(--fail .) ;;
            shellcheck) args=("${shell_files[@]}") ;;
        esac
        run_stage "Lint: $tool" "${runner[@]}" "${args[@]}" || :
    done
else
    if check_system=$("${nix_cmd[@]}" eval --impure --raw --expr builtins.currentSystem); then
        for check in formatting statix deadnix shellcheck; do
            run_stage "Lint: $check" "${nix_cmd[@]}" build --no-link --no-update-lock-file \
                "$flake_ref#checks.$check_system.$check" || :
        done
    else
        failed=1
    fi
fi

# Keep collecting independent failures, but do not spend time evaluating outputs
# after source checks fail.
if ((failed == 0)); then
    if [[ $mode == full || $mode == ci ]]; then
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
        for i in "${!integrated_hosts[@]}"; do
            host=${integrated_hosts[i]}
            user=${integrated_users[i]}
            run_stage "Integrated home: $host/$user activation derivation" "${nix_cmd[@]}" eval \
                "$flake_ref#nixosConfigurations.$host.config.home-manager.users.$user.home.activationPackage.drvPath" \
                --json --no-update-lock-file || :
        done
        for host in "${system_hosts[@]}"; do
            run_stage "System: $host assertions" "${nix_cmd[@]}" eval \
                "$flake_ref#nixosConfigurations.$host.config.assertions" --json --no-update-lock-file \
                --apply 'assertions: let failed = builtins.filter (item: !item.assertion) assertions; in if failed == [] then true else throw (builtins.concatStringsSep "\n" (map (item: item.message) failed))' || :
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
# Fixtures are independent of source/output failures and always get a chance to run.
for suite in "${fixtures[@]}"; do
    if "$sandbox"; then
        run_stage "Fixtures: $suite" bash "tests/test-$suite.sh" || :
    else
        if [[ -n $check_system ]]; then
            run_stage "Fixtures: $suite ($check_system)" "${nix_cmd[@]}" build --no-link --no-update-lock-file \
                "$flake_ref#checks.$check_system.$suite-fixtures" || :
        else
            failed=1
        fi
    fi
done
if ((failed)); then
    echo "Validation incomplete or failed (scope: $mode). No full build or activation ran." >&2
    exit 1
fi
printf '\nSelected checks passed (scope: %s). No full build or activation ran.\n' "$mode"
