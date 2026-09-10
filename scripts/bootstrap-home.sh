#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${NIXOS_REPO:-https://git.tacomafia.net/kylhill/nixos.git}"
REPO_DIR="${NIXOS_DIR:-$HOME/nixos}"
HM_CONFIG="${HM_CONFIG:-wsl}"
HM_RELEASE="${HM_RELEASE:-26.05}"

log() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

[[ "$(uname -s)" == "Linux" ]] ||
    die "This script must be run inside Linux/WSL."

if ! grep -qi microsoft /proc/version; then
    echo "WARNING: This does not appear to be WSL."
fi

[[ "$(ps -p 1 -o comm=)" == "systemd" ]] ||
    die "systemd is not running."

# ---------------------------------------------------------------------------
# Minimal Ubuntu prerequisites
# ---------------------------------------------------------------------------

log "Installing Ubuntu prerequisites"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    xz-utils

# ---------------------------------------------------------------------------
# Nix
# ---------------------------------------------------------------------------

if command -v nix >/dev/null 2>&1; then
    log "Nix is already installed"
else
    log "Installing Nix"

    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT

    curl -fsSL https://nixos.org/nix/install -o "$installer"
    sh "$installer" --daemon

    rm -f "$installer"
    trap - EXIT
fi

# Make Nix available immediately in this shell.
if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

command -v nix >/dev/null 2>&1 ||
    die "Nix installation completed but nix is unavailable."

# ---------------------------------------------------------------------------
# Enable flakes
# ---------------------------------------------------------------------------

log "Configuring Nix"

mkdir -p "$HOME/.config/nix"
NIX_CONF="$HOME/.config/nix/nix.conf"

touch "$NIX_CONF"

if ! grep -Eq \
    '^[[:space:]]*experimental-features[[:space:]]*=.*nix-command.*flakes' \
    "$NIX_CONF"; then
    echo 'experimental-features = nix-command flakes' >> "$NIX_CONF"
fi

# ---------------------------------------------------------------------------
# Clone configuration repository
# ---------------------------------------------------------------------------

if [[ -d "$REPO_DIR/.git" ]]; then
    log "NixOS repository already exists at $REPO_DIR"
else
    log "Cloning $REPO"

    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO" "$REPO_DIR"
fi

# ---------------------------------------------------------------------------
# SOPS age identity
# ---------------------------------------------------------------------------

AGE_DIR="$HOME/.config/sops/age"
AGE_FILE="$AGE_DIR/keys.txt"

if [[ -s "$AGE_FILE" ]]; then
    log "SOPS age identity already exists"
else
    log "Installing SOPS age bootstrap identity"

    echo
    echo "Paste your AGE-SECRET-KEY value."
    echo "Input will not be displayed."
    echo

    IFS= read -r -s -p "Age key: " AGE_SECRET_KEY
    echo

    if [[ "$AGE_SECRET_KEY" != AGE-SECRET-KEY-* ]]; then
        unset AGE_SECRET_KEY
        die "Input does not look like an age secret key."
    fi

    install -d -m 0700 "$AGE_DIR"

    (
        umask 077
        printf '%s\n' "$AGE_SECRET_KEY" > "$AGE_FILE"
    )

    unset AGE_SECRET_KEY
    chmod 0600 "$AGE_FILE"
fi

# ---------------------------------------------------------------------------
# Home Manager
# ---------------------------------------------------------------------------

log "Activating Home Manager configuration: $HM_CONFIG"

cd "$REPO_DIR"

nix run "github:nix-community/home-manager/release-${HM_RELEASE}" -- \
    switch \
    --flake ".#${HM_CONFIG}"

log "Bootstrap complete"

echo
echo "Configuration: $REPO_DIR#$HM_CONFIG"
echo
echo "Future updates:"
echo "    cd $REPO_DIR"
echo "    git pull"
echo "    nix flake update"
echo "    home-manager switch --flake .#$HM_CONFIG"
