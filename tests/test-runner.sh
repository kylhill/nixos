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
# Use the same manifest as direct syntax/ShellCheck and native flake checks.
while IFS= read -r file; do
    mkdir -p "$fixture_dir/repo/$(dirname -- "$file")"
    cp "$repo_dir/$file" "$fixture_dir/repo/$file"
    chmod u+w "$fixture_dir/repo/$file"
done < "$repo_dir/tests/shell-files"
cp "$repo_dir/tests/shell-files" "$fixture_dir/repo/tests/"
# Stub nested suites: test selection/failures without recursively running ourselves.
for suite in runner apply; do
    cat > "$fixture_dir/repo/tests/test-$suite.sh" <<EOF
#!/usr/bin/env bash
printf 'fixture $suite\\n' >> "\$FIXTURE_LOG"
[[ \${FAIL_FIXTURE:-} != $suite ]]
EOF
done
for tool in nix nixfmt statix deadnix shellcheck pwsh; do
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
    calls=$(< "$FIXTURE_LOG")
}
require_call() { [[ $calls == *"$1"* ]] || { echo "Missing call: $1" >&2; exit 1; }; }
reject_call() { [[ $calls != *"$1"* ]] || { echo "Unexpected call: $1" >&2; exit 1; }; }
reject_nix() { if grep -q '^nix ' "$FIXTURE_LOG"; then echo 'Unexpected Nix invocation' >&2; exit 1; fi; }
reject_checks() {
    [[ -z $calls ]]
    [[ $(< "$fixture_dir/output") != *'==>'* ]]
}

run_case 2
reject_checks
run_case 2 --sandbox
reject_checks
run_case 2 --path
reject_checks
run_case 2 --sandbox --path
reject_checks
run_case 0 --sandbox --option-home syntax programs.git.enable
require_call 'path:.#homeConfigurations.syntax.config.programs.git.enable --json --no-update-lock-file'
reject_call 'nixfmt'
reject_call 'activationPackage'
run_case 0 --sandbox --option-integrated-home pang14 kyleh programs.git.enable
require_call 'path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh.programs.git.enable --json --no-update-lock-file'
reject_call 'nixfmt'
reject_call 'activationPackage'
run_case 0 --path --option-home syntax programs.git.enable
require_call 'path:.#homeConfigurations.syntax.config.programs.git.enable'
run_case 1 --sandbox --option-home missing programs.git.enable
for invalid in '' '.programs.git' 'programs..git' 'programs.git."enable"' 'programs.git/enable'; do
    run_case 2 --sandbox --option-home syntax "$invalid"
    reject_checks
done
run_case 2 --sandbox --option-home syntax programs.git.enable --lint
reject_checks
run_case 2 --sandbox --option-integrated-home pang14 kyleh programs.git.enable --home gateway
reject_checks
run_case 0 --sandbox --lint
reject_call 'flake check'
reject_call 'homeConfigurations'
reject_call 'devShells'
reject_call 'nixosConfigurations'
require_call 'nixfmt'
require_call 'scripts/bootstrap-home.sh'
require_call 'existing.nix'
require_call 'untracked.nix'
reject_call 'deleted.nix'
reject_nix

run_case 0 --sandbox --home gateway --home oci --integrated-home pang14 kyleh --integrated-home other_host other-user --dev aarch64-linux
require_call 'homeConfigurations.gateway.activationPackage.drvPath'
require_call 'homeConfigurations.oci.activationPackage.drvPath'
require_call 'devShells.aarch64-linux'
require_call 'path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh.home.activationPackage.drvPath --json --no-update-lock-file'
require_call 'path:.#nixosConfigurations.other_host.config.home-manager.users.other-user.home.activationPackage.drvPath'
require_call 'nix NIX_REMOTE=daemon '
require_call "NIX_CACHE_HOME=$NIX_CACHE_HOME"
require_call "XDG_CACHE_HOME=$XDG_CACHE_HOME"
reject_call 'flake check'
reject_call 'homeConfigurations.syntax'
reject_call 'nix build'
reject_call 'system.build.toplevel'

run_case 0 --sandbox --integrated-home pang14 kyleh
require_call 'nixosConfigurations.pang14.config.home-manager.users.kyleh.home.activationPackage.drvPath'
reject_call 'homeConfigurations'
reject_call 'devShells'
reject_call 'flake check'
reject_call 'system.build'

run_case 0 --sandbox --home gateway
reject_call 'nixosConfigurations'
reject_call 'devShells'
run_case 0 --sandbox --dev x86_64-linux --dev aarch64-linux
require_call 'devShells.x86_64-linux'
require_call 'devShells.aarch64-linux'
reject_call 'homeConfigurations'
reject_call 'nixosConfigurations'
reject_call 'flake check'

run_case 0 --sandbox --full
require_call 'flake check path:. --no-build --all-systems'
require_call 'path:.#homeConfigurations --no-update-lock-file'
reject_call 'runner-fixtures'
reject_call 'apply-fixtures'

run_case 0 --ci
[[ $(grep -c 'builtins.currentSystem' "$FIXTURE_LOG") == 1 ]]
require_call 'flake check . --no-build --all-systems'
require_call '.#homeConfigurations --no-update-lock-file'
for suite in runner apply windows; do
    require_call "build --no-link --no-update-lock-file .#checks.x86_64-linux.$suite-fixtures"
done

export FAIL_NIX_MATCH=runner-fixtures
run_case 1 --ci
require_call '.#homeConfigurations --no-update-lock-file'
require_call 'runner-fixtures'
unset FAIL_NIX_MATCH

run_case 0 --path --lint
require_call 'build --no-link --no-update-lock-file path:.#checks.x86_64-linux.formatting'
reject_call 'flake check'

export FAIL_TOOL=statix
run_case 1 --sandbox --full
require_call 'shellcheck'
reject_call 'flake check'
unset FAIL_TOOL

# Missing development tools fail clearly while available linters still run.
mv "$fixture_dir/tools/bin/statix" "$fixture_dir/statix"
run_case 1 --sandbox --lint
require_call 'shellcheck'
[[ $(< "$fixture_dir/output") == *'expected on PATH from the default development shell'* ]]
mv "$fixture_dir/statix" "$fixture_dir/tools/bin/statix"

run_case 1 --sandbox --home missing --home gateway
require_call 'homeConfigurations.gateway'
# Every selected output still runs after an independent evaluation fails.
for failed_output in homeConfigurations.gateway nixosConfigurations.pang14 devShells.x86_64-linux; do
    export FAIL_NIX_MATCH=$failed_output
    run_case 1 --sandbox --home gateway --integrated-home pang14 kyleh --integrated-home other user --dev x86_64-linux --dev aarch64-linux
    require_call 'homeConfigurations.gateway'
    require_call 'nixosConfigurations.pang14'
    require_call 'nixosConfigurations.other'
    require_call 'devShells.x86_64-linux'
    require_call 'devShells.aarch64-linux'
done
export FAIL_NIX_MATCH='flake check'
run_case 1 --sandbox --full
require_call 'path:.#homeConfigurations --no-update-lock-file'
unset FAIL_NIX_MATCH
for scope in --home --dev --system; do
    run_case 2 "$scope"
    reject_checks
    run_case 2 "$scope" 'bad.name'
    reject_checks
    run_case 2 "$scope" --lint
    reject_checks
    run_case 2 --full "$scope" syntax
    reject_checks
    run_case 2 "$scope" syntax --lint
    reject_checks
done
run_case 2 --integrated-home
reject_checks
run_case 2 --integrated-home pang14
reject_checks
for invalid in '' bad.name 'bad/user' 'bad user' '"quoted"' --lint 123host; do
    run_case 2 --integrated-home "$invalid" kyleh
    reject_checks
    run_case 2 --integrated-home pang14 "$invalid"
    reject_checks
done
for exclusive in --lint --full --ci; do
    run_case 2 "$exclusive" --integrated-home pang14 kyleh
    reject_checks
    run_case 2 --integrated-home pang14 kyleh "$exclusive"
    reject_checks
done
run_case 2 --unknown
reject_checks
run_case 2 --offline
reject_checks
run_case 2 --lint --full
reject_checks
run_case 2 --full --ci
reject_checks
run_case 0 --help
reject_checks
run_case 0 --sandbox --help
reject_checks
# System scopes never request a system closure or unrelated homes.
run_case 0 --sandbox --option-system pang14 services.openssh.enable
require_call 'path:.#nixosConfigurations.pang14.config.services.openssh.enable --json --no-update-lock-file'
reject_call 'nixfmt'
reject_call 'system.build'
run_case 0 --sandbox --system pang14 --home gateway
require_call 'nixosConfigurations.pang14.config.assertions'
require_call 'homeConfigurations.gateway.activationPackage.drvPath'
reject_call 'system.build'
reject_call 'flake check'
export FAIL_NIX_MATCH=nixosConfigurations.pang14.config.assertions
run_case 1 --sandbox --system pang14 --system other
require_call 'nixosConfigurations.other.config.assertions'
unset FAIL_NIX_MATCH

# Fixtures combine with lint/selected/full scopes, are deduplicated, and need no Nix.
run_case 0 --sandbox --fixtures runner
require_call 'fixture runner'
reject_call 'fixture apply'
reject_nix
run_case 0 --sandbox --fixtures all --lint --fixtures runner
require_call 'fixture runner'
require_call 'fixture apply'
require_call 'pwsh'
[[ $(grep -c '^fixture runner$' "$FIXTURE_LOG") == 1 ]]
reject_nix
run_case 0 --sandbox --ci
require_call 'fixture runner'
require_call 'fixture apply'
require_call 'pwsh'
reject_call 'nix build'
run_case 0 --sandbox --home gateway --fixtures apply
require_call 'homeConfigurations.gateway.activationPackage.drvPath'
require_call 'fixture apply'
export FAIL_FIXTURE=runner
run_case 1 --sandbox --fixtures runner --fixtures apply --home gateway
require_call 'homeConfigurations.gateway.activationPackage.drvPath'
require_call 'fixture apply'
unset FAIL_FIXTURE
export FAIL_TOOL=statix
run_case 1 --sandbox --home gateway --fixtures runner
require_call 'fixture runner'
reject_call 'homeConfigurations'
unset FAIL_TOOL
mv "$fixture_dir/tools/bin/pwsh" "$fixture_dir/pwsh"
run_case 1 --sandbox --fixtures windows --fixtures apply
require_call 'fixture apply'
[[ $(< "$fixture_dir/output") == *'Cannot run pwsh'* ]]
mv "$fixture_dir/pwsh" "$fixture_dir/tools/bin/pwsh"
for args in runner apply windows; do
    run_case 2 --fixtures "$args" --option-system pang14 services.openssh.enable
    reject_checks
    run_case 2 --option-system pang14 services.openssh.enable --fixtures "$args"
    reject_checks
done
run_case 2 --fixtures
reject_checks
run_case 2 --fixtures unknown
reject_checks
for invalid in '' 'bad..option' 'bad/option'; do
    run_case 2 --option-system pang14 "$invalid"
    reject_checks
done
run_case 2 --option-system
reject_checks
run_case 2 --option-system pang14
reject_checks
run_case 2 --option-system bad.host services.openssh.enable
reject_checks

# Real Git whitespace and Bash syntax failures gate evaluation, but leave
# independent lint/fixture checks running. No fake Git or fake Bash here.
printf 'if then\n' >> "$fixture_dir/repo/update.sh"
run_case 1 --sandbox --home gateway --fixtures apply
require_call 'shellcheck'
require_call 'fixture apply'
reject_call 'homeConfigurations'
cp "$repo_dir/update.sh" "$fixture_dir/repo/update.sh"
git -C "$fixture_dir/repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm baseline
printf '{}   \n' > "$fixture_dir/repo/existing.nix"
run_case 1 --sandbox --home gateway
require_call 'shellcheck'
reject_call 'homeConfigurations'
git -C "$fixture_dir/repo" add existing.nix
printf '{}\n' > "$fixture_dir/repo/existing.nix"
run_case 1 --sandbox --home gateway
require_call 'shellcheck'
reject_call 'homeConfigurations'
echo 'Validation runner fixtures passed.'
