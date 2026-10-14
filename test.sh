#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sandbox=false
flake_ref=path:.
mode=
eval_refs=()
eval_applies=()
fixtures=()
usage() {
    echo 'usage: ./test.sh [--sandbox] [--path] SCOPE ...'
    echo '  An explicit scope is required; --lint, --full, --ci and --native-checks exclude selected outputs.'
    echo '  --native-checks build native lint derivations and any selected fixtures (no configuration evaluation)'
    echo '  --ci            full validation plus all fixture suites'
    echo '  --fixtures SUITE lint and runner/eval/apply/windows/all fixtures; repeatable and combinable'
    echo '  --system HOST   lint and evaluate system assertions, without a system build'
    echo '  --option-system HOST OPTION'
    echo '                  inspect non-secret NixOS options, repeatable without lint'
    echo '  --full          lint, evaluate all flake outputs and standalone homes (no host build)'
    echo '  --lint          source checks only; no host, home, or development output evaluation'
    echo '  --home NAME     lint and evaluate a selected home activation derivation; repeatable'
    echo '  --integrated-home HOST USER'
    echo '                  lint and evaluate only an integrated home activation derivation'
    echo '  --dev SYSTEM    lint and evaluate all development shells for a system; repeatable'
    echo '  --option-home NAME OPTION'
    echo '                  inspect non-secret standalone home options, repeatable without lint'
    echo '  --option-integrated-home HOST USER OPTION'
    echo '                  inspect non-secret integrated home options, repeatable without lint'
    echo '  --home, --integrated-home, --system and --dev are repeatable and combinable.'
    echo '  --fixtures combines with lint, selected outputs, full evaluation or native checks; option scopes are exclusive.'
    echo '  --sandbox       explicitly select the ordinary direct-tool loop; excludes --native-checks'
    echo '  --path          compatibility flag; all scopes already use path:. including untracked files'
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
add_eval() {
    eval_refs+=("$1")
    eval_applies+=("${2:-}")
}
assertions_check='assertions: let failed = builtins.filter (item: !item.assertion) assertions; in if failed == [] then true else throw (builtins.concatStringsSep "\n" (map (item: item.message) failed))'
while (($#)); do
    case "$1" in
        --sandbox) sandbox=true ;;
        --path) : ;;
        --lint|--full|--ci|--native-checks)
            [[ -z $mode || $mode == "${1#--}" ]] || die 'Do not combine exclusive validation scopes.'
            mode=${1#--}
            ;;
        --fixtures)
            [[ $# -ge 2 ]] || die '--fixtures requires runner, eval, apply, windows or all.'
            [[ $mode != option ]] || die 'An option check cannot be combined with fixtures.'
            case "$2" in
                runner|eval|apply|windows) add_fixture "$2" ;;
                all) for suite in runner eval apply windows; do add_fixture "$suite"; done ;;
                *) die '--fixtures requires runner, eval, apply, windows or all.' ;;
            esac
            shift
            ;;
        --home|--dev|--system)
            if [[ $# -lt 2 ]] || ! safe_attr "$2"; then
                die "$1 requires a safe attribute identifier (letter/underscore, then letters, digits, underscores or hyphens)."
            fi
            [[ -z $mode || $mode == selected ]] || die 'Do not combine exclusive validation scopes with selected outputs.'
            mode=selected
            case "$1" in
                --home) add_eval "homeConfigurations.$2.activationPackage.drvPath" ;;
                --dev) add_eval "devShells.$2" 'shells: builtins.mapAttrs (_: shell: shell.drvPath) shells' ;;
                --system) add_eval "nixosConfigurations.$2.config.assertions" "$assertions_check" ;;
            esac
            shift
            ;;
        --integrated-home)
            if [[ $# -lt 3 ]] || ! safe_attr "$2" || ! safe_attr "$3"; then
                die '--integrated-home requires HOST USER, each a safe attribute identifier (letter/underscore, then letters, digits, underscores or hyphens).'
            fi
            [[ -z $mode || $mode == selected ]] || die 'Do not combine exclusive validation scopes with selected outputs.'
            mode=selected
            add_eval "nixosConfigurations.$2.config.home-manager.users.$3.home.activationPackage.drvPath"
            shift 2
            ;;
        --option-home|--option-system)
            if [[ $# -lt 3 ]] || ! safe_attr "$2" || ! safe_option "$3"; then
                die "$1 requires NAME and a dotted OPTION path."
            fi
            [[ -z $mode || $mode == option ]] || die 'Option inspections cannot combine with completion scopes.'
            mode=option
            if [[ $1 == --option-home ]]; then
                add_eval "homeConfigurations.$2.config.$3"
            else
                add_eval "nixosConfigurations.$2.config.$3"
            fi
            shift 2
            ;;
        --option-integrated-home)
            if [[ $# -lt 4 ]] || ! safe_attr "$2" || ! safe_attr "$3" || ! safe_option "$4"; then
                die '--option-integrated-home requires HOST, USER and a dotted OPTION path.'
            fi
            [[ -z $mode || $mode == option ]] || die 'Option inspections cannot combine with completion scopes.'
            mode=option
            add_eval "nixosConfigurations.$2.config.home-manager.users.$3.$4"
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
[[ $mode != native-checks || $sandbox == false ]] || die '--native-checks cannot combine with --sandbox; use direct scopes or explicit small nix builds.'
if [[ $mode == ci ]]; then
    for suite in runner eval apply windows; do add_fixture "$suite"; done
fi
export NIX_CONFIG="${NIX_CONFIG:-}"$'\nexperimental-features = nix-command flakes'
cd "$repo_dir"

selection_expression() {
    local i value selection='flake: builtins.listToAttrs ['
    for i in "${!eval_refs[@]}"; do
        # All path segments pass safe_attr/safe_option before reaching here.
        value="flake.${eval_refs[i]}"
        if [[ -n ${eval_applies[i]} ]]; then value="(${eval_applies[i]}) ($value)"; fi
        selection+=" { name = \"${eval_refs[i]}\"; value = $value; }"
    done
    printf '%s ]' "$selection"
}
if [[ $mode == option ]]; then
    if ((${#eval_refs[@]} == 1)); then
        exec nix eval "$flake_ref#${eval_refs[0]}" --json --no-update-lock-file
    fi
    # Inspection stdout is exactly one JSON value. Failed batches return Nix's
    # error without printing partial results or running completion checks.
    exec nix eval "$flake_ref#lib.validation" --json --no-update-lock-file \
        --apply "$(selection_expression)"
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
printf 'Validation scope: %s; outputs: %s; fixtures: %s\n' \
    "$mode" "${eval_refs[*]:-none}" "${fixtures[*]:-none}"
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

build_native_checks() {
    local system check
    local refs=()
    if ! system=$(nix eval --impure --raw --expr builtins.currentSystem); then
        failed=1
        return
    fi
    for check in formatting statix deadnix shellcheck; do
        refs+=("$flake_ref#checks.$system.$check")
    done
    for check in "${fixtures[@]}"; do
        refs+=("$flake_ref#checks.$system.$check-fixtures")
    done
    if ! run_stage 'Native checks' nix build --keep-going --no-link --no-update-lock-file "${refs[@]}"; then
        # Evaluation failures may stop the batch before independent builds run.
        for check in "${refs[@]}"; do
            run_stage "Native check: $check" nix build --no-link --no-update-lock-file "$check" || :
        done
    fi
}
evaluate_selected() {
    local i
    local args
    if ((${#eval_refs[@]} > 1)); then
        if run_stage 'Selected output evaluation' nix eval "$flake_ref#lib.validation" --json \
            --no-update-lock-file --apply "$(selection_expression)"; then
            return
        fi
    fi
    # One output stays direct. A failed batch retries every member, retaining
    # detailed errors and checking the outputs after the first failure.
    for i in "${!eval_refs[@]}"; do
        args=(eval "$flake_ref#${eval_refs[i]}" --json --no-update-lock-file)
        if [[ -n ${eval_applies[i]} ]]; then args+=(--apply "${eval_applies[i]}"); fi
        run_stage "Evaluation: ${eval_refs[i]}" nix "${args[@]}" || :
    done
}

if [[ $mode == native-checks ]]; then
    build_native_checks
else
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

    # Keep collecting independent failures, but do not spend time evaluating outputs
    # after source checks fail.
    if ((failed == 0)); then
        if [[ $mode == full || $mode == ci ]]; then
            run_stage 'Full flake evaluation (no builds)' nix flake check "$flake_ref" \
                --no-build --all-systems --no-update-lock-file || :
            run_stage 'All standalone home activation derivations' nix eval \
                "$flake_ref#homeConfigurations" --no-update-lock-file --json \
                --apply 'homes: builtins.mapAttrs (_: home: home.activationPackage.drvPath) homes' || :
        else
            evaluate_selected
        fi
    else
        echo 'Source checks incomplete or failed; output evaluation skipped.' >&2
    fi
    # Fixtures are independent of source/output failures and always run.
    for suite in "${fixtures[@]}"; do
        run_stage "Fixtures: $suite" bash "tests/test-$suite.sh" || :
    done
fi
if ((failed)); then
    echo "Validation incomplete or failed (scope: $mode). No full build or activation ran." >&2
    exit 1
fi
printf '\nSelected checks passed (scope: %s). No full build or activation ran.\n' "$mode"
