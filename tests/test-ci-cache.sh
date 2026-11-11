#!/usr/bin/env bash
# Disposable cache fixtures: no real Nix builds, credentials, or production cache.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$(mktemp -d)
trap 'rm -rf -- "$fixture_dir"' EXIT
export CI_NIX_BINARY_CACHE_DIR="$fixture_dir/cache"
export CACHE_TEST_LOG="$fixture_dir/calls"
month=$(date -u +%Y-%m)
previous_month=$(date -u -d "$month-01 -1 month" +%Y-%m)
mkdir -p "$fixture_dir/bin" "$CI_NIX_BINARY_CACHE_DIR/2000-01/nar" \
    "$CI_NIX_BINARY_CACHE_DIR/$month/nar" "$CI_NIX_BINARY_CACHE_DIR/$previous_month/nar"
for generation in 2000-01 "$previous_month" "$month"; do
    touch "$CI_NIX_BINARY_CACHE_DIR/$generation/nix-cache-info" \
        "$CI_NIX_BINARY_CACHE_DIR/$generation/fixture.narinfo" \
        "$CI_NIX_BINARY_CACHE_DIR/$generation/nar/fixture.nar.zst"
done
cat > "$fixture_dir/bin/nix" <<'NIX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CACHE_TEST_LOG"
case "$1" in
    store) : ;;
    eval) echo x86_64-linux ;;
    build)
        [[ ${FAIL_BUILD:-} != 1 ]] || exit 31
        ln -s /nix/store/fixture-shell "${@: -1}"
        ;;
    copy)
        [[ ${FAIL_COPY:-} != 1 ]] || exit 32
        ;;
    develop)
        if [[ $3 == bash ]]; then
            [[ ${FAIL_PROBE:-} != 1 ]] || exit 33
        else
            [[ $3 == fixture-validation && $4 == 'argument with spaces' ]]
            # Validation must keep cleanup excluded for its entire lifetime.
            if flock -n -x "$CI_NIX_BINARY_CACHE_DIR/.lifecycle.lock" true; then
                echo 'Validation lost the lifecycle lock' >&2
                exit 99
            fi
            [[ $NIX_CONFIG == *'trusted=true&priority=10'* ]]
            [[ $NIX_CONFIG == *'trusted=true&priority=20'* ]]
            [[ $NIX_CONFIG == *'require-sigs = true'* ]]
            exit "${COMMAND_STATUS:-0}"
        fi
        ;;
    *) exit 98 ;;
esac
NIX
chmod +x "$fixture_dir/bin/nix"
export PATH="$fixture_dir/bin:$PATH"
export NIX_CONFIG='require-sigs = true'
helper="$repo_dir/scripts/ci/with-nix-cache.sh"
run_case() {
    local expected=$1 status=0
    shift
    : > "$CACHE_TEST_LOG"
    bash "$helper" fixture-validation 'argument with spaces' "$@" > "$fixture_dir/output" 2>&1 || status=$?
    if [[ $status != "$expected" ]]; then
        cat "$fixture_dir/output" >&2
        echo "Expected status $expected, got $status" >&2
        exit 1
    fi
}
# Whole expired generations disappear; current and previous metadata/NARs survive.
run_case 0
[[ ! -e "$CI_NIX_BINARY_CACHE_DIR/2000-01" ]]
for generation in "$previous_month" "$month"; do
    [[ -f "$CI_NIX_BINARY_CACHE_DIR/$generation/fixture.narinfo" ]]
    [[ -f "$CI_NIX_BINARY_CACHE_DIR/$generation/nar/fixture.nar.zst" ]]
done
grep -Fq "store info --store file://$CI_NIX_BINARY_CACHE_DIR/$month" "$CACHE_TEST_LOG"
grep -Fq "copy --to file://$CI_NIX_BINARY_CACHE_DIR/$month?compression=zstd" "$CACHE_TEST_LOG"
# A concurrent reader defers cleanup; the next idle invocation completes it.
mkdir -p "$CI_NIX_BINARY_CACHE_DIR/2000-01/nar"
exec 7>"$CI_NIX_BINARY_CACHE_DIR/.lifecycle.lock"
flock -s 7
run_case 0
[[ -d "$CI_NIX_BINARY_CACHE_DIR/2000-01/nar" ]]
flock -u 7
exec 7>&-
run_case 0
[[ ! -e "$CI_NIX_BINARY_CACHE_DIR/2000-01" ]]
# Failures before publication stop validation. Export failures do not mask results.
export FAIL_BUILD=1
run_case 31
if grep -Eq '^copy|fixture-validation' "$CACHE_TEST_LOG"; then exit 1; fi
unset FAIL_BUILD
export FAIL_PROBE=1
run_case 33
if grep -Eq '^copy|fixture-validation' "$CACHE_TEST_LOG"; then exit 1; fi
unset FAIL_PROBE
export FAIL_COPY=1 COMMAND_STATUS=7
run_case 7
grep -q 'could not publish' "$fixture_dir/output"
unset FAIL_COPY COMMAND_STATUS
# Both CI jobs mount archives rather than a shared writable /nix store.
for workflow in pull-request renovate; do
    grep -Fq '/opt/cache/nix:/opt/cache/nix' "$repo_dir/.forgejo/workflows/$workflow.yml"
    if grep -Fq '/opt/cache/nix:/nix' "$repo_dir/.forgejo/workflows/$workflow.yml"; then exit 1; fi
    grep -Fq 'bash scripts/ci/with-nix-cache.sh ./test.sh --ci' "$repo_dir/.forgejo/workflows/$workflow.yml"
done
echo 'CI binary cache fixtures passed.'
