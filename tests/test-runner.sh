#!/usr/bin/env bash
# Test orchestration with fake Nix/tools: never evaluate or build real outputs.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/repo/scripts" "$fixture_dir/repo/tests/fixtures" "$fixture_dir/tools/bin"
# Only these real utilities may cross the fake-tool boundary.
for tool in bash cat chmod cp dirname git grep ln mkdir mktemp mv rm; do
    ln -s "$(command -v "$tool")" "$fixture_dir/tools/bin/$tool"
done
# Exercise the real manifest without depending on unrelated script contents.
# Only the runner/update scripts remain real inputs.
while IFS= read -r file; do
    mkdir -p "$fixture_dir/repo/$(dirname -- "$file")"
    case "$file" in
        test.sh|update.sh)
            cp "$repo_dir/$file" "$fixture_dir/repo/$file" ;;
        *) printf '#!/usr/bin/env bash\n' > "$fixture_dir/repo/$file" ;;
    esac
    chmod u+w "$fixture_dir/repo/$file"
done < "$repo_dir/tests/shell-files"
cp "$repo_dir/tests/shell-files" "$fixture_dir/repo/tests/"
# Stub nested suites: test selection/failures without recursively running ourselves.
for suite in runner eval apply windows; do
    cat > "$fixture_dir/repo/tests/test-$suite.sh" <<EOF
#!/usr/bin/env bash
printf '%s\\0' fixture '' '' '' 1 $suite >> "\$FIXTURE_LOG"
[[ \${FAIL_FIXTURE:-} != $suite ]]
EOF
done
for tool in nix nixfmt statix deadnix shellcheck; do
    {
        printf '#!%s\n' "$(command -v bash)"
        tail -n +2 "$repo_dir/tests/fixtures/validation-tool"
    } > "$fixture_dir/tools/bin/$tool"
    chmod +x "$fixture_dir/tools/bin/$tool"
done
export PATH="$fixture_dir/tools/bin"
export HOME="$fixture_dir/home"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir -p "$HOME"
git -C "$fixture_dir/repo" init -q
printf '{}\n' > "$fixture_dir/repo/existing.nix"
printf '{}\n' > "$fixture_dir/repo/deleted.nix"
git -C "$fixture_dir/repo" add existing.nix deleted.nix
rm "$fixture_dir/repo/deleted.nix"
printf '{}\n' > "$fixture_dir/repo/untracked.nix"
export FIXTURE_LOG="$fixture_dir/calls"
# Model Codex's shell environment policy without changing the ordinary XDG cache.
export TMPDIR="$fixture_dir"
export NIX_CACHE_HOME="$fixture_dir/nixos-codex-nix-cache"
export NIX_REMOTE=daemon
export XDG_CACHE_HOME="$fixture_dir/ordinary-cache"
mkdir -p "$NIX_CACHE_HOME"
load_calls() { mapfile -d '' -t call_fields < "$FIXTURE_LOG"; }
select_calls() {
    local tool=$1 i=0
    call_offsets=()
    while ((i < ${#call_fields[@]})); do
        if [[ ${call_fields[i]} == "$tool" ]]; then call_offsets+=("$i"); fi
        i=$((i + 5 + call_fields[i + 4]))
    done
}
find_call() {
    local tool=$1 offset wanted arg found matches
    shift
    select_calls "$tool"
    for offset in "${call_offsets[@]}"; do
        matches=true
        for wanted in "$@"; do
            found=false
            for ((arg=offset+5; arg<offset+5+call_fields[offset+4]; arg++)); do
                if [[ ${call_fields[arg]} == "$wanted" ]]; then found=true; break; fi
            done
            if ! "$found"; then matches=false; break; fi
        done
        if "$matches"; then return 0; fi
    done
    return 1
}
require_call() { find_call "$@" || { echo "Missing invocation: $*" >&2; exit 1; }; }
reject_call() { if find_call "$@"; then echo "Unexpected invocation: $*" >&2; exit 1; fi; }
find_arg_like() {
    local tool=$1 pattern=$2 offset arg
    select_calls "$tool"
    for offset in "${call_offsets[@]}"; do
        for ((arg=offset+5; arg<offset+5+call_fields[offset+4]; arg++)); do
            # This helper deliberately matches an argument against a glob.
            # shellcheck disable=SC2053
            if [[ ${call_fields[arg]} == $pattern ]]; then return 0; fi
        done
    done
    return 1
}
require_arg_like() { find_arg_like "$@" || { echo "Missing argument matching: $*" >&2; exit 1; }; }
reject_arg_like() { if find_arg_like "$@"; then echo "Unexpected argument matching: $*" >&2; exit 1; fi; }
require_count() {
    select_calls "$1"
    [[ ${#call_offsets[@]} == "$2" ]] || { echo "Expected $2 $1 calls, got ${#call_offsets[@]}" >&2; exit 1; }
}
run_case() {
    local expected=$1 status=0
    shift
    : > "$FIXTURE_LOG"
    bash "$fixture_dir/repo/test.sh" "$@" > "$fixture_dir/output" 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        cat "$fixture_dir/output"
        echo "Expected exit $expected, got $status: $*" >&2
        exit 1
    fi
    load_calls
}
reject_checks() {
    [[ ${#call_fields[@]} == 0 ]]
    [[ $(< "$fixture_dir/output") != *'==>'* ]]
}
reject_configuration() {
    reject_arg_like nix '*homeConfigurations*'
    reject_arg_like nix '*nixosConfigurations*'
    reject_arg_like nix '*devShells*'
}

# Verify the recording boundary itself; arguments are not shell word strings.
: > "$FIXTURE_LOG"
nix eval '' 'two words' $'two\nlines' --json > /dev/null
load_calls
require_call nix '' 'two words' $'two\nlines' --json
reject_call nix two words
require_count nix 1

# Update selection and failure propagation use the same argument-aware fake.
: > "$FIXTURE_LOG"
bash "$fixture_dir/repo/update.sh" nixpkgs > "$fixture_dir/output" 2>&1
load_calls
require_call nix flake update --flake path:. nixpkgs
: > "$FIXTURE_LOG"
status=0
FAIL_NIX_MATCH=update bash "$fixture_dir/repo/update.sh" > "$fixture_dir/output" 2>&1 || status=$?
[[ $status == 1 && $(< "$fixture_dir/output") != *'Inputs updated.'* ]]

for flags in '' '--sandbox' '--path' '--sandbox --path'; do
    read -r -a flag_args <<< "$flags"
    run_case 2 "${flag_args[@]}"
    reject_checks
done

# Each option route maps its distinct operands without source checks.
for kind in home system integrated-home; do
    case "$kind" in
        home) target=(syntax); ref=homeConfigurations.syntax.config.programs.git.enable ;;
        system) target=(pang14); ref=nixosConfigurations.pang14.config.programs.git.enable ;;
        integrated-home) target=(pang14 kyleh); ref=nixosConfigurations.pang14.config.home-manager.users.kyleh.programs.git.enable ;;
    esac
    run_case 0 --sandbox "--option-$kind" "${target[@]}" programs.git.enable
    require_call nix eval "path:.#$ref" --json --no-update-lock-file
    require_count nix 1
    reject_call nix build
    reject_call nix flake check
    reject_call nixfmt
    run_case 2 "--option-$kind"
    reject_checks
done
run_case 1 --option-home missing programs.git.enable
run_case 0 --path --option-home syntax programs.git.enable
require_call nix eval path:.#homeConfigurations.syntax.config.programs.git.enable

# Repeated and mixed inspection routes still use one invocation without lint.
run_case 0 --option-home syntax programs.git.enable --option-home syntax home.homeDirectory --option-system pang14 services.openssh.enable --option-integrated-home pang14 kyleh programs.git.enable
require_count nix 1
require_call nix eval path:.#lib.validation --json --no-update-lock-file --apply
reject_call nixfmt
reject_call fixture

# Direct tools are the default, with compatibility flags preserving that path.
for flags in '' '--sandbox' '--path'; do
    read -r -a flag_args <<< "$flags"
    run_case 0 "${flag_args[@]}" --lint
    reject_call nix
    require_call nixfmt --check existing.nix untracked.nix
    reject_arg_like nixfmt '*deleted.nix*'
    require_call shellcheck scripts/bootstrap-home.sh
    require_call statix check .
    require_call deadnix --fail .
done

# Fake tests check orchestration; eval fixtures check selection semantics.
run_case 0 --sandbox --home gateway --home oci --integrated-home pang14 kyleh --system pang14 --dev aarch64-linux
require_count nix 1
require_call nix eval path:.#lib.validation --json --no-update-lock-file --apply
reject_call nix build
reject_call nix flake check
select_calls nix
offset=${call_offsets[0]}
[[ ${call_fields[offset+1]} == daemon && ${call_fields[offset+2]} == "$NIX_CACHE_HOME" && ${call_fields[offset+3]} == "$XDG_CACHE_HOME" ]]

# Singles stay direct. Duplicate/hyphenated names remain one batch.
run_case 0 --home gateway
require_call nix eval path:.#homeConfigurations.gateway.activationPackage.drvPath
require_count nix 1
run_case 0 --integrated-home pang14 kyleh
require_call nix eval path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh.home.activationPackage.drvPath
reject_arg_like nix '*homeConfigurations*'
run_case 0 --system pang14
require_call nix eval path:.#nixosConfigurations.pang14.config.assertions --apply
run_case 0 --dev x86_64-linux
require_call nix eval path:.#devShells.x86_64-linux --apply
run_case 0 --home other-home --home gateway --home gateway
require_count nix 1

# A failed batch checks each member, and fixtures still run after all failures.
run_case 1 --home missing --home gateway --fixtures apply
require_call nix eval path:.#homeConfigurations.missing.activationPackage.drvPath
require_call nix eval path:.#homeConfigurations.gateway.activationPackage.drvPath
require_count nix 3
require_call fixture apply
for failed_output in homeConfigurations.gateway nixosConfigurations.pang14 devShells.x86_64-linux; do
    export FAIL_NIX_MATCH=$failed_output
    run_case 1 --home gateway --integrated-home pang14 kyleh --system pang14 --dev x86_64-linux --dev aarch64-linux --fixtures apply
    require_call nix eval path:.#homeConfigurations.gateway.activationPackage.drvPath
    require_call nix eval path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh.home.activationPackage.drvPath
    require_call nix eval path:.#nixosConfigurations.pang14.config.assertions
    require_call nix eval path:.#devShells.x86_64-linux
    require_call nix eval path:.#devShells.aarch64-linux
    require_count nix 6
    require_call fixture apply
done
unset FAIL_NIX_MATCH

for scope in --full --ci; do
    run_case 0 "$scope"
    require_call nix flake check path:. --no-build --all-systems --no-update-lock-file
    require_call nix eval path:.#homeConfigurations --json --apply
    reject_call nix build
    if [[ $scope == --ci ]]; then
        require_call fixture runner
        require_call fixture apply
        require_call fixture windows
    else
        reject_call fixture
    fi
done
export FAIL_NIX_MATCH=check
run_case 1 --full --fixtures apply
require_call nix eval path:.#homeConfigurations
require_call fixture apply
unset FAIL_NIX_MATCH

# Reproducibility checks are explicit, native-only and batched independently.
run_case 0 --native-checks --fixtures all --fixtures runner
require_count nix 2
require_call nix eval --impure --raw --expr builtins.currentSystem
for check in formatting statix deadnix shellcheck runner-fixtures eval-fixtures apply-fixtures windows-fixtures; do
    require_call nix build --keep-going --no-link --no-update-lock-file "path:.#checks.x86_64-linux.$check"
done
reject_call nixfmt
reject_call fixture
reject_call fixture windows
reject_configuration
export FAIL_NIX_MATCH=checks.x86_64-linux.statix
run_case 1 --native-checks --fixtures all
require_count nix 10
for check in formatting statix deadnix shellcheck runner-fixtures eval-fixtures apply-fixtures windows-fixtures; do
    require_call nix build --no-link --no-update-lock-file "path:.#checks.x86_64-linux.$check"
done
unset FAIL_NIX_MATCH
export FAIL_NIX_MATCH=builtins.currentSystem
run_case 1 --native-checks --fixtures apply
reject_call nix build
unset FAIL_NIX_MATCH

# Source failures gate outputs, but preserve independent lint and fixtures.
export FAIL_TOOL=statix
run_case 1 --home gateway --fixtures runner
require_call shellcheck
require_call fixture runner
reject_call nix
unset FAIL_TOOL
mv "$fixture_dir/tools/bin/statix" "$fixture_dir/statix"
run_case 1 --full --fixtures apply
require_call shellcheck
require_call fixture apply
reject_call nix
[[ $(< "$fixture_dir/output") == *'expected on PATH from the default development shell'* ]]
mv "$fixture_dir/statix" "$fixture_dir/tools/bin/statix"

run_case 0 --fixtures runner
require_count fixture 1
require_call fixture runner
reject_call nix
reject_call fixture windows
run_case 0 --fixtures all --lint --fixtures runner
require_count fixture 4
require_call fixture runner
require_call fixture apply
require_call fixture windows
reject_call nix
export FAIL_FIXTURE=runner
run_case 1 --fixtures runner --fixtures apply --home gateway
require_call nix eval path:.#homeConfigurations.gateway.activationPackage.drvPath
require_call fixture apply
unset FAIL_FIXTURE
export FAIL_FIXTURE=windows
run_case 1 --fixtures windows --fixtures apply
require_call fixture apply
unset FAIL_FIXTURE

# Shared validators get one representative per invalid input class. Routes
# retain their own missing-operand checks because their arities differ.
for invalid in '' bad.name --lint 'bad/user' 'bad user' '"quoted"' 123host; do
    run_case 2 --home "$invalid"
    reject_checks
done
for invalid in '' '.programs.git' 'programs..git' 'programs.git."enable"' 'programs.git/enable'; do
    run_case 2 --option-home syntax "$invalid"
    reject_checks
done
for scope in --home --dev --system; do
    run_case 2 "$scope"
    reject_checks
done
for args in '--integrated-home' '--integrated-home pang14' '--option-home syntax' '--option-system pang14' '--option-integrated-home pang14' '--option-integrated-home pang14 kyleh'; do
    read -r -a missing_args <<< "$args"
    run_case 2 "${missing_args[@]}"
    reject_checks
done
# The integrated routes validate both identity operands.
for scope in --integrated-home --option-integrated-home; do
    extra=()
    if [[ $scope == --option-integrated-home ]]; then extra=(programs.git.enable); fi
    run_case 2 "$scope" bad.host kyleh "${extra[@]}"
    reject_checks
    run_case 2 "$scope" pang14 bad.user "${extra[@]}"
    reject_checks
done
run_case 2 --option-system bad.host services.openssh.enable
reject_checks
# Check both ordering directions for each distinct mode transition. Fixture
# suite names share one guard, so a representative suite is enough here.
for exclusive in --lint --full --ci --native-checks; do
    run_case 2 "$exclusive" --home syntax
    reject_checks
    run_case 2 --home syntax "$exclusive"
    reject_checks
    run_case 2 "$exclusive" --option-home syntax programs.git.enable
    reject_checks
    run_case 2 --option-home syntax programs.git.enable "$exclusive"
    reject_checks
done
run_case 2 --home syntax --option-home syntax programs.git.enable
reject_checks
run_case 2 --option-home syntax programs.git.enable --home syntax
reject_checks
run_case 2 --fixtures runner --option-home syntax programs.git.enable
reject_checks
run_case 2 --option-home syntax programs.git.enable --fixtures runner
reject_checks
for flags in '--unknown' '--offline' '--lint --full' '--full --ci' '--sandbox --native-checks' '--native-checks --sandbox' '--native-checks --full'; do
    read -r -a flag_args <<< "$flags"
    run_case 2 "${flag_args[@]}"
    reject_checks
done
for flags in '--help' '--sandbox --help'; do
    read -r -a flag_args <<< "$flags"
    run_case 0 "${flag_args[@]}"
    reject_checks
done
run_case 2 --fixtures
reject_checks
run_case 2 --fixtures unknown
reject_checks
# Real Git and Bash failures are not mocked.
printf 'if then\n' >> "$fixture_dir/repo/update.sh"
run_case 1 --home gateway --fixtures apply
require_call shellcheck
require_call fixture apply
reject_call nix
cp "$repo_dir/update.sh" "$fixture_dir/repo/update.sh"
git -C "$fixture_dir/repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm baseline
printf '{}   \n' > "$fixture_dir/repo/existing.nix"
run_case 1 --home gateway
require_call shellcheck
reject_call nix
git -C "$fixture_dir/repo" add existing.nix
printf '{}\n' > "$fixture_dir/repo/existing.nix"
run_case 1 --home gateway
require_call shellcheck
reject_call nix
echo 'Validation runner fixtures passed.'
