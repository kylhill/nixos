#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${NIXOS_REPO:-https://git.tacomafia.net/kylhill/nixos.git}"
REPO_DIR="${NIXOS_DIR:-$HOME/nixos}"
HM_CONFIG=wsl
EXPECTED_USER=kyleh
EXPECTED_HOME=/home/kyleh

log() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

[[ $# == 0 ]] || die "This script does not accept arguments."

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

[[ "$(uname -s)" == "Linux" ]] ||
    die "This script must be run inside Linux/WSL."

[[ $EUID != 0 ]] || die "Run this script as $EXPECTED_USER, not as root."

BOOTSTRAP_USER=$(id -un)
[[ $BOOTSTRAP_USER == "$EXPECTED_USER" ]] ||
    die "The WSL configuration requires user $EXPECTED_USER; current user is $BOOTSTRAP_USER."
[[ $HOME == "$EXPECTED_HOME" ]] ||
    die "The WSL configuration requires HOME=$EXPECTED_HOME; current HOME is $HOME."

grep -qi microsoft /proc/sys/kernel/osrelease ||
    die "This script must be run inside WSL."

[[ $(uname -m) == x86_64 ]] ||
    die "The WSL configuration requires x86_64; current architecture is $(uname -m)."

if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
    cat >&2 <<'EOF'

ERROR: systemd is not running in this WSL distribution.

Add the following to /etc/wsl.conf, preserving any existing settings:

    [boot]
    systemd=true

EOF

    if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
        printf 'Then run this from PowerShell:\n\n    wsl.exe --terminate "%s"\n' \
            "$WSL_DISTRO_NAME" >&2
    else
        cat >&2 <<'EOF'
Then run this from PowerShell:

    wsl.exe --shutdown
EOF
    fi

    echo "Start the distribution again and rerun this script." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Minimal Ubuntu prerequisites
# ---------------------------------------------------------------------------

log "Installing Ubuntu prerequisites"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    nix-bin \
    nix-setup-systemd

sudo usermod --append --groups nix-users "$BOOTSTRAP_USER"

# Ubuntu's package installation can leave these pre-existing Nix state
# directories at 0755, preventing users from creating their profile and GC-root
# directories during the first Home Manager activation. Reapply the package's
# tmpfiles rules, which set both per-user parent directories to 01777.
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/nix-daemon.conf

# Ubuntu enables and starts both units even though a running daemon prevents
# systemd from also listening on its socket. Use the always-on service mode.
sudo systemctl disable --now nix-daemon.socket
sudo systemctl enable --now nix-daemon.service

command -v nix >/dev/null 2>&1 ||
    die "Nix installation completed but nix is unavailable."

# ---------------------------------------------------------------------------
# Enable flakes
# ---------------------------------------------------------------------------

log "Configuring Nix"

mkdir -p "$HOME/.config/nix"
NIX_CONF="$HOME/.config/nix/nix.conf"

touch "$NIX_CONF"

if ! awk '
    /^[[:space:]]*(extra-)?experimental-features[[:space:]]*=/ {
        line = $0
        sub(/[[:space:]]*#.*/, "", line)
        if (line ~ /(^|[[:space:]])nix-command([[:space:]]|$)/ &&
            line ~ /(^|[[:space:]])flakes([[:space:]]|$)/) {
            found = 1
        }
    }
    END { exit !found }
' "$NIX_CONF"; then
    echo 'extra-experimental-features = nix-command flakes' >> "$NIX_CONF"
fi

# ---------------------------------------------------------------------------
# Clone configuration repository
# ---------------------------------------------------------------------------

if [[ -d "$REPO_DIR/.git" ]]; then
    log "NixOS repository already exists at $REPO_DIR"
elif [[ -e $REPO_DIR ]]; then
    die "$REPO_DIR already exists but is not a Git repository; move it or choose NIXOS_DIR."
else
    log "Cloning $REPO"

    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO" "$REPO_DIR"
fi

# ---------------------------------------------------------------------------
# Home Manager
# ---------------------------------------------------------------------------

log "Activating Home Manager configuration: $HM_CONFIG"

cd "$REPO_DIR"

configured_home=$(sudo -u "$BOOTSTRAP_USER" env HOME="$HOME" \
    nix eval --raw \
    "path:$REPO_DIR#homeConfigurations.${HM_CONFIG}.config.home.homeDirectory") ||
    die "Repository does not expose a usable homeConfigurations.$HM_CONFIG target."
[[ $configured_home == "$EXPECTED_HOME" ]] ||
    die "homeConfigurations.$HM_CONFIG targets $configured_home, expected $EXPECTED_HOME."

activation_env=(
    "HOME=$HOME"
    "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$UID}"
    "DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$UID/bus}"
)

if ! command -v home-manager >/dev/null 2>&1; then
    activation_env+=("HOME_MANAGER_BACKUP_EXT=pre-home-manager")
fi

activation_package=$(sudo -u "$BOOTSTRAP_USER" env HOME="$HOME" \
    nix build --no-link --print-out-paths \
    "path:$REPO_DIR#homeConfigurations.${HM_CONFIG}.activationPackage")

sudo -u "$BOOTSTRAP_USER" env "${activation_env[@]}" "$activation_package/activate"

# ---------------------------------------------------------------------------
# Optional SSH identity provisioning
# ---------------------------------------------------------------------------

echo
IFS= read -r -s -p \
    "Optional SOPS age secret key (leave blank to skip SSH identity provisioning): " \
    sops_age_key
echo

if [[ -n $sops_age_key ]]; then
    ssh_dir="$HOME/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    provision_dir=$(mktemp -d)
    cleanup_provision_dir() {
        rm -rf -- "$provision_dir"
    }
    trap cleanup_provision_dir EXIT

    age_key_file="$provision_dir/keys.txt"
    printf '%s\n' "$sops_age_key" > "$age_key_file"
    unset sops_age_key
    chmod 600 "$age_key_file"

    age_keygen="$activation_package/home-path/bin/age-keygen"
    sops="$activation_package/home-path/bin/sops"
    [[ -x $age_keygen && -x $sops ]] ||
        die "The WSL Home Manager profile does not provide age and sops."

    "$age_keygen" -y "$age_key_file" >/dev/null ||
        die "The supplied SOPS age secret key is invalid."

    private_key="$provision_dir/id_ed25519"
    public_key="$provision_dir/id_ed25519.pub"
    SOPS_AGE_KEY_FILE="$age_key_file" "$sops" decrypt \
        --extract '["ssh"]["private-key"]' \
        --output "$private_key" \
        "$REPO_DIR/secrets/home.yaml"
    SOPS_AGE_KEY_FILE="$age_key_file" "$sops" decrypt \
        --extract '["ssh"]["public-key"]' \
        --output "$public_key" \
        "$REPO_DIR/secrets/home.yaml"

    install -m 0600 "$private_key" "$ssh_dir/id_ed25519"
    install -m 0644 "$public_key" "$ssh_dir/id_ed25519.pub"

    cleanup_provision_dir
    trap - EXIT
    log "Provisioned the shared SSH identity and discarded the SOPS age key"
else
    log "Skipping SOPS age key and SSH identity provisioning"
fi

log "Bootstrap complete"

echo
echo "Configuration: $REPO_DIR#$HM_CONFIG"
echo
echo "Future updates:"
echo "    cd $REPO_DIR"
echo "    git pull"
echo "    ./apply.sh switch"
