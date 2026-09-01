# NixOS infrastructure

Flake-based NixOS and Home Manager configuration, beginning with the System76
Pangolin 14 (`pang14`) and structured for later migration of the OCI VPS,
gateway, NAS/application server, and other hosts from `~/infra`.

## Repository model

- `hosts/pang14/` contains only hardware, storage, and host composition.
- `modules/nixos/` contains reusable system profiles.
- `modules/home/kyleh/` contains the declarative user environment.
- `lib/inventory.nix` contains stable, non-secret identity and network data.
- `secrets/` documents encrypted host-secret provisioning.

The flake exposes `nixosConfigurations.pang14`. Home Manager is integrated into
that system configuration, so there is no separate user activation step.

The existing Ansible and dotfiles repositories remain authoritative for
non-Nix hosts during migration. On `pang14`, this repository replaces Dotbot,
TPM, lazy.nvim, and Mason with Home Manager, Nix-managed tmux plugins, and
Nixvim.

## Normal operation

Test a generation without making it the boot default:

```bash
./apply.sh test
```

Build, activate, and make it the boot default:

```bash
./apply.sh
```

`apply.sh` first runs `nix flake check`, then invokes `nixos-rebuild` for the
integrated NixOS and Home Manager configuration. It accepts `build`, `boot`,
`switch`, or `test`, defaulting to `switch`, and does not depend on `nh`.

Update pinned inputs explicitly, inspect the lock-file diff, then test and
switch:

```bash
./update.sh
git diff -- flake.lock
./apply.sh test
./apply.sh
```

`update.sh` updates `flake.lock` and runs `nix flake check`, but deliberately
does not activate the result. Commit the reviewed lock file together with any
related configuration changes.

Activate the on-demand WireGuard profiles after secrets are provisioned:

```bash
vpn home up
vpn home status
vpn home down

vpn oci up
vpn oci status
vpn oci down
```

Starting either profile stops the other. `home` is a split tunnel for the home
IPv4 and ULA networks. `oci` is a full IPv4/IPv6 tunnel.

## Storage design

Only this device is a valid destructive target:

```text
/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B97472
```

The WD Blue SN580 with serial `24144M801597` contains Windows and Ubuntu and
must not be modified.

Disko creates a 2 GB EFI system partition, 40 GB resume swap, and a ZFS `rpool`
using the remaining space. Persistent datasets back `/`, `/nix`, `/home`, and
`/var`. Root, home, and var retain 24 hourly, 7 daily, 4 weekly, and 3 monthly
snapshots; `/nix` is excluded. ZFS trim runs weekly and scrub runs monthly.

ZRAM is disabled. Kernel zswap uses zstd and zsmalloc as a compressed cache in
front of the persistent swap partition, capped at 20% of RAM. The same 40 GB
partition is the hibernation resume device.

## Fresh installation

These steps intentionally separate verification, destructive formatting, and
installation. Run them from a NixOS 26.05 installer booted in UEFI mode.

The live installer may not enable flakes globally. Set this once in its shell;
commands run through `sudo` below pass it explicitly where needed:

```bash
export NIX_CONFIG='experimental-features = nix-command flakes'
```

1. Complete [the secrets bootstrap](secrets/README.md), commit the encrypted
   files, and back up the private age identities and recovered WireGuard keys.

2. Clone this repository, enter it, and run the read-only preflight:

   ```bash
   ./scripts/install-preflight
   ```

   Read both printed serials. Stop if the destructive target is not the Kingston
   KC3000.

3. Evaluate and build before touching storage:

   ```bash
   nix flake check
   nix build .#nixosConfigurations.pang14.config.system.build.toplevel
   ```

4. Destroy, format, and mount only the declared Kingston target:

   ```bash
   sudo env NIX_CONFIG="$NIX_CONFIG" nix run .#disko -- \
     --mode destroy,format,mount ./hosts/pang14/disko.nix
   ```

5. Provision and verify the host age identity in the mounted `rpool/var`.
   This is mandatory: without it, sops-nix cannot decrypt the login password
   hash and the new account will be locked:

   ```bash
   sudo ./scripts/install-host-key /secure/location/pang14-host.txt
   sudo stat /mnt/var/lib/sops-nix/key.txt
   ```

6. Compare the detected hardware configuration with `hosts/pang14/hardware.nix`:

   ```bash
   sudo nixos-generate-config --root /mnt --show-hardware-config
   ```

   Do not replace the declarative Disko filesystem definitions with generated
   filesystem entries.

7. Install and reboot:

   ```bash
   sudo env NIX_CONFIG="$NIX_CONFIG" \
     nixos-install --flake .#pang14 --no-root-passwd
   sudo reboot
   ```

## Post-install verification

```bash
zpool status rpool
zfs list
systemctl list-timers 'zfs-*'
swapon --show
cat /sys/module/zswap/parameters/enabled
cat /sys/module/zswap/parameters/compressor
cat /sys/module/zswap/parameters/zpool
cat /sys/module/zswap/parameters/max_pool_percent
systemctl status sops-install-secrets --no-pager
loginctl show-session "$XDG_SESSION_ID" -p Type
pgrep -a Xwayland || true
```

Expected results:

- `rpool` is healthy and all four datasets are mounted.
- The 40 GB disk swap is active; no `/dev/zram*` device exists.
- zswap reports enabled, `zstd`, `zsmalloc`, and `20`.
- The desktop session type is `wayland` and no Xwayland process exists.
- Firefox and VS Code launch natively.
- `vpn home up` reaches LAN/internal DNS.
- `vpn oci up` changes both public IPv4 and IPv6 egress to OCI.
- Suspend-then-hibernate resumes with applications intact.
- Windows and Ubuntu remain bootable from the firmware boot menu.

ZFS snapshots are rollback aids, not backups. Off-host laptop backup is deferred
to a later reusable backup module.
