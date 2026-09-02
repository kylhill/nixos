# NixOS infrastructure

Flake-based NixOS and Home Manager configuration for the System76 Pangolin 14
(`pang14`). The module and inventory layout is designed to accommodate future
desktop, server, VPS, NAS, and router hosts without copying whole host
configurations or imposing laptop policy on every machine.

The flake exposes `nixosConfigurations.pang14`. Home Manager is integrated into
that system configuration, so system and user changes activate together.

For hosts not yet represented here, the existing Ansible and dotfiles
repositories remain authoritative. On `pang14`, this repository replaces
Dotbot, lazy.nvim, and Mason with Home Manager and Nixvim.

## Repository map

- `flake.nix` pins dependencies and constructs every host in
  `lib/inventory.nix`.
- `hosts/pang14/` selects capabilities and owns hardware, boot, storage, and
  host-specific policy.
- `modules/nixos/` contains reusable system capabilities and roles.
- `modules/home/kyleh/` contains the integrated Home Manager configuration.
- `lib/inventory.nix` contains stable, non-secret host, user, and network data.
- `secrets/pang14.yaml` contains only sops-encrypted values; key provisioning
  and editing procedures are in [secrets/README.md](secrets/README.md).

Contributor and coding-agent constraints live in [AGENTS.md](AGENTS.md). That
file intentionally does not duplicate the operator procedures below.

## Normal operation

Promote a change progressively. Stop at the first failure instead of combining
linting, building, activation, and switching into one unobserved step.

### 1. Inspect and run lightweight checks

Enter the pinned development environment when the required tools are not
already available, then run the repository checks:

```bash
nix develop
./test.sh
```

The script stops at the first failure. It evaluates every flake output with
`nix flake check --no-build`, then builds only the formatting, Statix, Deadnix,
and ShellCheck derivations. It never builds or activates the `pang14` system
closure.

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

Commit the reviewed lock-file update separately from unrelated changes. Both
NetworkManager WireGuard profiles are intentional full IPv4/IPv6 tunnels. They
appear in GNOME as `Home VPN` and `OCI VPN` after secrets are provisioned.

## Fresh installation

These steps intentionally separate verification, destructive formatting, and
installation for `pang14`. Read [hosts/pang14/disko.nix](hosts/pang14/disko.nix)
and the [secrets bootstrap guide](secrets/README.md) in full first. Run the
commands from a NixOS 26.05 installer booted in UEFI mode.

The installation destroys only the Kingston KC3000 at:

```text
/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B97472
```

It creates EFI and swap partitions plus the ZFS datasets declared in Disko.
The WD Blue SN580 with serial `24144M801597` contains Windows and Ubuntu and
must not be modified. The preflight script verifies both disks before any
destructive command is run.

The live installer may not enable flakes globally. Set this once in its shell;
commands run through `sudo` below pass it explicitly where needed:

```bash
export NIX_CONFIG='experimental-features = nix-command flakes'
```

1. Clone this repository and enter it. Confirm that `.sops.yaml` and the
   encrypted `secrets/pang14.yaml` are present.

2. Make both private age identities available from secure backups as described
   in [secrets/README.md](secrets/README.md). Do not continue if the host key or
   required service credentials cannot be recovered.

3. Run the read-only preflight:

   ```bash
   ./scripts/install-preflight
   ```

   Read both printed serials. Stop if the destructive target is not the Kingston
   KC3000.

4. Evaluate and build before touching storage:

   ```bash
   nix flake check --no-build
   nix build .#nixosConfigurations.pang14.config.system.build.toplevel
   ```

5. Destroy, format, and mount only the declared Kingston target:

   ```bash
   sudo env NIX_CONFIG="$NIX_CONFIG" nix run .#disko -- \
     --mode destroy,format,mount ./hosts/pang14/disko.nix
   ```

6. Provision and verify the host age identity in the mounted `rpool/var`.
   This is mandatory: without it, sops-nix cannot decrypt the login password
   hash and the new account will be locked:

   ```bash
   sudo ./scripts/install-host-key /secure/location/pang14-host.txt
   sudo stat /mnt/var/lib/sops-nix/key.txt
   ```

7. Compare the detected hardware configuration with `hosts/pang14/hardware.nix`:

   ```bash
   sudo nixos-generate-config --root /mnt --show-hardware-config
   ```

   Do not replace the declarative Disko filesystem definitions with generated
   filesystem entries.

8. Install and reboot:

   ```bash
   sudo env NIX_CONFIG="$NIX_CONFIG" \
     nixos-install --flake .#pang14 --no-root-passwd
   sudo reboot
   ```

### Outstanding `pang14` storage work

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
