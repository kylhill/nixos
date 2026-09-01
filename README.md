# NixOS infrastructure

Flake-based NixOS and Home Manager configuration, beginning with the System76
Pangolin 14 (`pang14`) and intended to grow into a heterogeneous fleet of
laptops and desktops, NAS and homelab servers, VPSes, and gateway routers.
Reusable capability and role modules should make that expansion possible
without copying complete host configurations, while host composition and
hardware-specific policy remain explicit under `hosts/`.

The existing OCI VPS, gateway, NAS/application server, and other hosts in
`~/infra` can be migrated incrementally. Framework abstractions are retained
when they represent credible reuse across future hosts or host classes; the
repository does not require every abstraction to have a second consumer before
those migrations begin.

The flake exposes `nixosConfigurations.pang14`. Home Manager is integrated into
that system configuration, so system and user changes activate together.

The existing Ansible and dotfiles repositories remain authoritative for
non-Nix hosts during migration. On `pang14`, this repository replaces Dotbot,
TPM, lazy.nvim, and Mason with Home Manager, Nix-managed tmux plugins, and
Nixvim.

Repository structure, coding conventions, validation requirements, and agent
guidance live in [AGENTS.md](AGENTS.md).

## Normal operation

Promote a change progressively. Stop at the first failure instead of combining
linting, building, activation, and switching into one unobserved step.

### 1. Inspect and run lightweight checks

These checks are appropriate on any development host. They evaluate the flake
and may download small formatter or linter dependencies, but they do not build
the `pang14` system closure:

```bash
./test.sh
```

The script stops at the first failure. It evaluates every flake output
without building it, and then runs the four lightweight lint derivations
individually. It never builds or activates the `pang14` system closure.

Review the complete diff after automated checks pass:

```bash
git diff --stat
git diff
```

### 2. Build on `pang14` without activating

Run the remaining stages on `pang14`, where the system closure is expected to
be cached. A build catches package, module, and activation-script failures but
does not change the running or boot-default configuration:

```bash
./apply.sh build
```

### 3. Temporarily activate and verify

`test` activates the candidate for the running system without making it the
boot default:

```bash
./apply.sh test
```

Exercise the behavior affected by the change, then check the general system
health before promoting it:

```bash
systemctl --failed
systemctl status home-manager-kyleh.service --no-pager
systemctl status sops-install-secrets.service --no-pager
systemctl status NetworkManager-ensure-profiles.service --no-pager
systemctl list-timers 'zfs-*'
nmcli connection show
```

Also verify relevant interactive behavior such as login, sudo, networking,
audio, suspend, and the changed Home Manager applications. A reboot returns to
the previous boot-default generation; the systemd-boot menu provides older
generations if a normal boot ever fails.

### 4. Promote to the boot default

Only after the temporary activation and runtime checks pass, review and commit
the candidate so the boot-default generation corresponds to a durable source
revision. Then activate that revision and make it the default for the next
boot:

```bash
git status --short
git diff
# Stage only the reviewed files and commit them.
git commit
./apply.sh switch
```

Confirm that there are no failed units and that the worktree still represents
the revision that produced the running generation:

```bash
systemctl --failed
git status --short
```

### Updating pinned inputs

Treat an input update like any other change: update without activation, review
the lock-file diff, and then run the complete progression above:

```bash
./update.sh
git diff -- flake.lock
```

Both NetworkManager WireGuard profiles are intentional full IPv4/IPv6 tunnels.
They are available from GNOME's network settings as `Home VPN` and `OCI VPN`
after secrets are provisioned.

## Storage design

Only this device is a valid destructive target:

```text
/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B97472
```

The WD Blue SN580 with serial `24144M801597` contains Windows and Ubuntu and
must not be modified.

Disko creates a 2 GB EFI system partition, 40 GB swap partition, and a ZFS `rpool`
using the remaining space. Persistent datasets back `/`, `/nix`, `/home`, and
`/var`. Home retains 24 hourly, 7 daily, 4 weekly, and 3 monthly snapshots;
root, `/nix`, and `/var` are excluded. ZFS trim runs weekly and scrub runs
monthly.

ZRAM is disabled. Kernel zswap uses zstd and zsmalloc as a compressed cache in
front of the persistent 40 GB swap partition, capped at 20% of RAM. The laptop
uses ordinary suspend; hibernation remains disabled because it is unsafe with
the ZFS system pool.

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
   nix flake check --no-build
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
- The desktop session type is `wayland`. Xwayland may run when an application
  needs the compatibility fallback.
- Firefox and VS Code launch natively on Wayland.
- Suspend and resume preserve the desktop session.
- Windows and Ubuntu remain bootable from the firmware boot menu.

ZFS snapshots are rollback aids, not backups. Off-host laptop backup is deferred
to a later reusable backup module.

## Outstanding storage work

- Update the existing pool to match the home-only snapshot policy after
  activating this configuration:

  ```bash
  sudo zfs set com.sun:auto-snapshot=false rpool/root
  sudo zfs set com.sun:auto-snapshot=false rpool/var
  sudo zfs set com.sun:auto-snapshot=true rpool/home
  ```

  These commands change snapshot eligibility but do not delete existing root
  or var snapshots. Inventory and prune those separately before considering
  the migration complete.

- Add LUKS encryption for both the ZFS system pool and the persistent swap
  partition during a planned destructive storage migration.
- Add encrypted, automated off-host backups with monitoring and periodic
  restore tests.
