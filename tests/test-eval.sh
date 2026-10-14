#!/usr/bin/env bash
# Real Nix evaluates an input-free fixture flake; no host modules or builds.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'chmod -R u+w -- "$fixture_dir"; rm -rf -- "$fixture_dir"' EXIT
mkdir -p "$fixture_dir/repo/tests" "$fixture_dir/bin" "$fixture_dir/home"
cp "$repo_dir/test.sh" "$fixture_dir/repo/"
cp "$repo_dir/tests/fixtures/eval-flake.nix" "$fixture_dir/repo/flake.nix"
printf 'test.sh\n' > "$fixture_dir/repo/tests/shell-files"
for tool in nixfmt statix deadnix shellcheck; do
    printf '#!%s\nexit 0\n' "$(command -v bash)" > "$fixture_dir/bin/$tool"
    chmod +x "$fixture_dir/bin/$tool"
done
export PATH="$fixture_dir/bin:$PATH"
export HOME="$fixture_dir/home"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
# A private fixture store allows the same tests inside native check sandboxes.
# One store/cache serves this suite; no inputs, downloads or builds are needed.
export NIX_REMOTE="local?root=$fixture_dir/store"
export NIX_CONF_DIR="$fixture_dir/config" NIX_USER_CONF_FILES=/dev/null
export NIX_CACHE_HOME="$fixture_dir/cache" XDG_CACHE_HOME="$fixture_dir/cache"
git -C "$fixture_dir/repo" init -q
run_case() {
    local expected=$1 status=0
    shift
    bash "$fixture_dir/repo/test.sh" --sandbox "$@" > "$fixture_dir/stdout" 2> "$fixture_dir/stderr" || status=$?
    if [[ $status != "$expected" ]]; then
        cat "$fixture_dir/stdout" "$fixture_dir/stderr"
        echo "Expected evaluation exit $expected, got $status: $*" >&2
        exit 1
    fi
}
# Mixed selection must parse, select exactly these values and leave the throwing
# unrelated configuration lazy. No real derivation is instantiated or built.
run_case 0 --home good --home other-home --integrated-home fixture user --system fixture --dev x86_64-linux
grep '^{' "$fixture_dir/stdout" | jq -e '. == {
    "homeConfigurations.good.activationPackage.drvPath": "good-home",
    "homeConfigurations.other-home.activationPackage.drvPath": "hyphenated-home",
    "nixosConfigurations.fixture.config.home-manager.users.user.home.activationPackage.drvPath": "integrated-home",
    "nixosConfigurations.fixture.config.assertions": true,
    "devShells.x86_64-linux": {"default": "development-shell"}
}' > /dev/null
run_case 0 --home other-home --home other-home
grep '^{' "$fixture_dir/stdout" | jq -e '. == {
    "homeConfigurations.other-home.activationPackage.drvPath": "hyphenated-home"
}' > /dev/null
# Assertions still fail with their message; healthy members after the failure
# receive an independent evaluation instead of disappearing behind the batch.
run_case 1 --system broken --home good
grep -q 'fixture assertion failure' "$fixture_dir/stderr"
grep -q 'Evaluation: homeConfigurations.good.activationPackage.drvPath: exit 0' "$fixture_dir/stdout"
grep -q '^"good-home"$' "$fixture_dir/stdout"
# Inspection stdout is valid JSON without stage logs. Single values retain their
# original shape, while repeatable inspections return a map of requested paths.
run_case 0 --option-home good home.homeDirectory
jq -e '. == "/fixture/home"' "$fixture_dir/stdout" > /dev/null
run_case 0 --option-home good programs.git.enable --option-home good home.homeDirectory \
    --option-system fixture services.openssh.enable --option-integrated-home fixture user programs.git.enable
jq -e '. == {
    "homeConfigurations.good.config.programs.git.enable": true,
    "homeConfigurations.good.config.home.homeDirectory": "/fixture/home",
    "nixosConfigurations.fixture.config.services.openssh.enable": false,
    "nixosConfigurations.fixture.config.home-manager.users.user.programs.git.enable": true
}' "$fixture_dir/stdout" > /dev/null
run_case 1 --option-home unrelated programs.git.enable --option-home good programs.git.enable
[[ ! -s $fixture_dir/stdout ]]
grep -q 'unselected home forced' "$fixture_dir/stderr"
echo 'Real Nix evaluation fixtures passed.'
