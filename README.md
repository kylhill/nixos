# NixOS infrastructure

Flake-based NixOS and Home Manager configuration for the System76 Pangolin 14
(`pang14`). The module and inventory layout is designed to accommodate future
desktop, server, VPS, NAS, and router hosts without copying whole host
configurations or imposing laptop policy on every machine.

The flake exposes `nixosConfigurations.pang14`. Home Manager is integrated into
that system configuration, so system and user changes activate together.

For hosts not yet represented here, the existing Ansible and dotfiles
repositories remain authoritative. Neovim is optional outside development: import `neovim-basic.nix` alongside
the common profile for basic editing, or `neovim-development.nix` for the full
editor (already imported by `development.nix`). Select one editor profile per
host. Both share `neovim.nix`: Solarized, editor options, the default editor,
and the Neovim man pager. Solarized is the basic profile's only plugin;
mini.ai text objects and mini.pairs auto-pairing belong to development.

The basic profile adds no LSPs, Treesitter, completion engines, external search
tools, formatters, provider runtimes, or clipboard utilities. It keeps the same
leader keys using native Neovim commands: file completion, buffer lists,
netrw, history, help, and internal `vimgrep` with quickfix results. Searches
use literal text and scan files under the current directory; they do not use
Snacks' Git-ignore-aware filtering. `<leader>sR` reopens search results rather
than resuming an arbitrary picker. The development profile retains the existing
Snacks pickers and full plugin configuration.

Both profiles enable Nixvim's `vimAlias` (a `vim` executable pointing to Neovim)
and `vimdiffAlias` (shell aliases for `nvim -d`). A separate Bash `vim` alias
is unnecessary. The common CLI profile alone installs no editor.

On `pang14`, this repository replaces
Dotbot, lazy.nvim, and Mason with Home Manager and Nixvim.

## Repository map

- `flake.nix` pins dependencies and constructs every host in
  `lib/inventory.nix`.
- `hosts/pang14/` selects capabilities and owns hardware, boot, storage, and
  host-specific policy.
- `modules/nixos/` contains reusable system capabilities and roles.
- `modules/home/kyleh/` contains portable Home Manager capabilities.
- `lib/inventory.nix` contains stable, non-secret host, user, and network data.
- `secrets/pang14.yaml` contains only sops-encrypted values; key provisioning
  and editing procedures are in [secrets/README.md](secrets/README.md).

Contributor and coding-agent constraints live in [AGENTS.md](AGENTS.md). That
file intentionally does not duplicate the operator procedures below.

## Home Manager composition

`modules/home/kyleh/admin-tools.nix` provides the administration tools in the
user's common baseline: curl, dnsutils, ncdu, rsync, and wget. Every
profile imports it through the common home module because the user administers
all of these systems.

`modules/home/kyleh/default.nix` is the common CLI profile: Bash, readline,
Starship, basic command-line utilities, Git, SSH, and htop. It accepts
`homeIdentity` (`name`, `fullName`, `email`, `homeDirectory`), `networkHosts`
(connection names and ports), and the pinned `inputs` as module arguments.
Shared home modules do not depend on NixOS's `osConfig`.

`development.nix` adds fd, fzf, jq, ripgrep, full Nixvim and its language tools,
direnv, GitHub CLI,
Codex, Copilot, lazygit, and editor-related shell settings. `workstation.nix`
adds graphical applications, GNOME preferences, and Bash VTE integration.
Both profiles also accept `latestPkgs`, an explicitly configured package set
from the locked `nixpkgs-unstable` input: development uses it for Codex, GitHub
CLI, and Copilot, while the workstation uses it for VS Code.
The workstation also installs Python alongside VS Code so extensions and tasks
can use it outside project-specific development environments.
Nixvim and nix-index-database module imports live with the home capabilities
that use them. The NixOS user boundary selects nix-index; standalone Ubuntu
homes omit it.

On `pang14`, `modules/nixos/user-kyleh.nix` adapts the system inventory into
Home Manager's identity/network arguments and selects the common profile.
The host sets `home.stateVersion` and explicitly selects development tools; the
GNOME system role selects the workstation profile. Git, OpenSSH, and shell
utilities are installed in the home environment rather than relying on their
presence in system packages. Account creation, groups, authorized keys, and
SSH secret provisioning remain system responsibilities.

Standalone Ubuntu profiles are kept separately in
`lib/home-inventory.nix`. `homeConfigurations.gateway` and
`homeConfigurations.oci` select the common Bash, Git, htop, and SSH baseline,
administration tools, and basic Nixvim; OCI targets AArch64.
`homeConfigurations.syntax` additionally supplies development tools, tmux with
automatic login attachment, a persistent local SSH agent, syntax-only Docker
shell helpers, and declarative mcp-grafana and mcp-nixos definitions. The
development profile integrates those definitions with Codex and Copilot CLI
and explicitly includes Bubblewrap and Socat for the AI command-line tools.
The repository development shell supplies mcp-nixos and ShellCheck. The MCP
registration references that same pinned mcp-nixos package directly, so Codex
does not depend on shell PATH lookup to start it.
Codex's settings are Home Manager-owned so its shared MCP integration can be
generated without discarding the user's existing preferences. Ubuntu's account,
groups, sudo policy, authorized keys, Nix bootstrap, and systemd linger remain
Ansible-owned.

Before activating the standalone home, coordinate the Ansible/Dotbot handoff
for owned paths and handlers and preserve existing files for rollback. Moving
tools from Ansible's latest-release installers to Nix also moves their updates
to the inputs locked by this flake. `pang14` continues to activate Home Manager
through NixOS.

## Normal operation

Promote a change progressively. Stop at the first failure instead of combining
linting, building, activation, and switching into one unobserved step.

### 1. Inspect and run lightweight checks

In Codex, run `./test.sh --sandbox` after modifying the repository. This includes
untracked files, checks whitespace and shell syntax, evaluates the flake and all
standalone Home Manager activation derivations with a persistent daemonless
store, and runs linters directly. It prefers available pinned tools, then tools
on PATH, then cache-only fetching of pinned tools. Network or mount restrictions
can block the last route; the script reports failures and exits nonzero rather
than silently skipping checks. No host closure is built.

For additional daemonless Nix commands in Codex, use
`./scripts/nix-sandbox`, optionally with `--offline` before the Nix subcommand
when all required inputs are cached. For example:

```bash
./scripts/nix-sandbox --offline eval path:.#homeConfigurations.syntax.activationPackage.drvPath
```

Outside Codex, `./test.sh` retains the targeted check-derivation workflow below.
Use `./test.sh --path` to include new files without staging them.

Enter the pinned development environment when the required tools are not
already available, then run the repository checks:

```bash
nix develop
./test.sh
```

Direnv users can approve the repository's `.envrc` once to enter the same
development environment automatically:

```bash
direnv allow
```

The script stops at the first failure. It evaluates every flake output with
`nix flake check --no-build`, explicitly evaluates every standalone Home Manager
activation derivation, then builds only the formatting, Statix, Deadnix, and
ShellCheck derivations. It never builds or activates the `pang14` system closure.

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

Exercise the behavior affected by the change before promoting it.

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
