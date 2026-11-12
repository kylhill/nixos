#!/usr/bin/env bash
# Run a repository command in an isolated store backed by shared NAR archives.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 COMMAND [ARG ...]" >&2
  exit 2
fi
cache_dir="${CI_NIX_BINARY_CACHE_DIR:-${INFRA_CI_BINARY_CACHE_DIR:-/opt/cache/nix/binary-v1}}"
mkdir -p "$cache_dir"
# Keep this inode stable. Every reader/writer holds a shared lock until exit;
# pruning takes it exclusively, without delaying already active jobs.
exec 8>"$cache_dir/.lifecycle.lock"
if flock -n -x 8; then
  oldest_month="$(date -u -d "$(date -u +%Y-%m-01) -1 month" +%Y-%m)"
  for generation in "$cache_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9]; do
    [[ -d "$generation" && ! -L "$generation" ]] || continue
    if [[ "${generation##*/}" < "$oldest_month" ]]; then
      echo "Removing expired binary cache generation: ${generation##*/}" >&2
      rm -rf -- "$generation"
    fi
  done
fi
flock -s -w 120 8
# Select the generation after acquiring the shared lock, including at month rollover.
month="$(date -u +%Y-%m)"
previous_month="$(date -u -d "$month-01 -1 month" +%Y-%m)"
previous_cache="$cache_dir/$previous_month"
cache_dir="$cache_dir/$month"
cache_url="file://$cache_dir"
mkdir -p "$cache_dir"
# Initialize once, and serialize publishers. Readers use Nix's atomic cache files.
(
  flock -w 120 9 || exit "$?"
  nix store info --store "$cache_url" >/dev/null
) 9>"$cache_dir/.publish.lock"
# Trust only this runner-local cache; keep signature checks for upstream caches.
# Failed substitutions may fall back to upstream caches or local builds.
substituters="$cache_url?trusted=true&priority=10"
if [[ -f "$previous_cache/nix-cache-info" ]]; then
  substituters+=" file://$previous_cache?trusted=true&priority=20"
fi
export NIX_CONFIG="${NIX_CONFIG:-}
extra-substituters = $substituters
fallback = true
narinfo-cache-negative-ttl = 0"

system="$(nix eval --impure --raw --expr builtins.currentSystem)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
nix build ".#devShells.$system.default" --out-link "$work_dir/environment"
nix develop --command bash -c 'command -v shellcheck >/dev/null'
# A cache is an optimization: a publication failure must not hide test results.
if ! (
  flock -w 120 9 || exit "$?"
  nix copy --to "$cache_url?compression=zstd" "$work_dir/environment"
) 9>"$cache_dir/.publish.lock"; then
  echo 'Warning: could not publish the development environment to the binary cache.' >&2
fi
nix develop --command "$@"
