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
The repository agent shell supplies ShellCheck and the other validation tools.
The Home Manager registration invokes the pinned mcp-nixos package directly by
store path. The repository-local Codex registration reaches the same package
through `nix run path:.#mcp-nixos`, so neither registration depends on finding
mcp-nixos on the shell `PATH`.
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

Choose a validation scope for the change. All test-runner scopes check source
whitespace, shell syntax, Nixfmt, Statix, Deadnix and ShellCheck first. Output
evaluation starts only when source checks pass. Each stage reports elapsed time
and failures; a scoped pass does not claim full coverage.

| Change | Fast feedback | Completion check |
| --- | --- | --- |
| Documentation/instructions | `git diff --check`, `git diff --cached --check`, verify referenced paths/commands | Same; no Nix evaluation |
| Shell helper | `bash -n SCRIPT`, `shellcheck SCRIPT`, relevant fixtures | `./test.sh --sandbox --lint`; for the runner, `bash tests/test-runner.sh` |
| One standalone home | Evaluate the changed setting | `./test.sh --sandbox --home syntax` |
| Shared home module | Evaluate one representative consumer | Select all affected homes; use `--full` if NixOS consumers are affected |
| Development shell/package | Evaluate the selected output | `./test.sh --sandbox --dev x86_64-linux`, plus a small targeted build if useful |
| Lock file/shared flake composition | Narrow checks while editing | `./test.sh --sandbox --full` |

`--home` and `--dev` are repeatable and can be combined. For example:

```bash
./test.sh --sandbox --offline --home gateway --home oci
./test.sh --sandbox --offline --dev x86_64-linux --dev aarch64-linux
```

Selected homes evaluate only their activation derivations; selected development
systems evaluate all their development-shell derivations. Neither evaluates a
NixOS configuration. `--lint` evaluates only tool metadata in sandbox mode.
No scope builds or activates a host or Home Manager environment.

The default remains `--full`: lint, all-system flake evaluation without builds,
and explicit evaluation of every standalone home activation derivation.
`flake check` alone does not traverse custom `homeConfigurations`.

Sandbox mode includes untracked files and runs linters directly. Runnable pinned
paths are cached by lock-file hash and architecture; otherwise available PATH
tools are used and reported. When tools are missing, their pinned paths are
resolved together, with binary-cache fetching if needed and source/remote builds
disabled. Once tools are available, lint-only runs do not invoke Nix or create
a temporary store.

`scripts/nix-sandbox` uses the system daemon and real `/nix/store` by default. It keeps
only writable metadata/tool-path caches under
`${TMPDIR:-/tmp}/nixos-codex-nix-${UID}/cache`. Daemon access failures are returned
directly; there is no probe or automatic store fallback. If a separate store is
needed, explicitly set `NIX_SANDBOX_BACKEND=local` to use the sibling `store`
directory. The default backend is `daemon`; `auto` is no longer accepted.
`NIX_SANDBOX_ROOT` overrides the cache/fallback root when a different writable
location is needed. For example:

```bash
NIX_SANDBOX_BACKEND=local ./test.sh --sandbox --offline --home gateway
```

`--offline` disables downloads without automatic online retries. If cached
inputs/tools are missing, rerun the same scope without `--offline` when network
access is available. For mount restrictions, use runnable tools or run the same
scope with `--path` outside Codex. Failed or unavailable checks exit nonzero.

For additional Nix commands in Codex, use
`./scripts/nix-sandbox`, optionally with `--offline` before the Nix subcommand
when all required inputs are cached. For example:

```bash
./scripts/nix-sandbox --offline eval path:.#homeConfigurations.syntax.activationPackage.drvPath
```

The repository's `.codex/config.toml` selects the `nixos-development` permission
profile with network access enabled. This profile permits the daemon socket;
a conversation started with a different effective policy can still reject it
with `Operation not permitted`. From an ordinary terminal, verify the profile
without building anything:

```bash
codex sandbox -P nixos-development -- nix --store daemon store info --json
codex sandbox -P nixos-development -- ./test.sh --sandbox --offline --home gateway
```

Start a new Codex session using that repository profile if the current session
retains a restrictive policy. Do not broaden filesystem permissions on the
daemon socket, change Nix trusted users, or disable sandboxing to fix this.
Even with daemon access, the helper's writable metadata cache is needed when
`~/.cache/nix` is read-only. Existing fallback stores are not automatically
deleted or migrated; unrelated temporary stores are not used by this workflow.

Outside Codex, the same scopes use daemon-backed Nix and build only the selected
formatter/linter check derivations. Use `--path` to include untracked files.

Ubuntu 26.04 LTS is the minimum supported non-NixOS development host. Install
both the Nix CLI and its systemd daemon setup from Ubuntu's `universe`
repository:

```bash
sudo apt install nix-bin nix-setup-systemd
nix --version
```

Ubuntu 26.04 supplies Nix 2.34.3. Older Ubuntu/Nix combinations are not tested
for this repository. The test runner enables `nix-command` and `flakes` for its
own invocations; enable those experimental features separately when invoking
`nix develop` directly if the host has not enabled them globally.

Enter the pinned agent environment when the required tools are not already
available, then run the repository checks:

```bash
nix develop .#agent
./test.sh --path --lint
```

Direnv users can approve the repository's `.envrc` once to enter the default
operator environment automatically:

```bash
direnv allow
```

Agents select the `agent` shell as directed by `AGENTS.md`; it supplies the
linters, structured-data/search helpers, and Nix evaluation and closure-review
tools. The `mcp-nixos` app keeps Codex MCP startup limited to that package. The
default `nix develop` and direnv shell is the operator environment: it shares the
routine editing and validation tools with the agent shell, then adds age, sops
and OpenSSL for the credential procedures in `secrets/README.md`. Shells, apps
and development checks are exposed for architectures present in either host
inventory, including AArch64 standalone homes.

The runner collects independent source failures before stopping output
evaluation, and collects independent evaluation failures within the selected
scope. Run `./test.sh --path --full` for the complete lightweight suite outside
Codex.

Review the complete diff after automated checks pass:

```bash
git diff --stat
git diff
```

### Review tools and closure analysis

The agent development shell includes the tools below. Check `command -v TOOL`
first; agents should reuse available executables or evaluated pinned executable
paths rather than realize a shell just to run one tool.
For lint-only work, use `./test.sh --sandbox --lint`; the runner resolves only
the required validation executables.

| Tool | Useful work | Limits and trade-offs |
| --- | --- | --- |
| Nix CLI (provided by the host) | `path-info` for size/reference metadata, `why-depends` for dependency causes, `store diff-closures` for comparisons | Start with explicit store paths; runtime and derivation graphs answer different questions |
| `nvd` | Readable package/version and size deltas between two existing closures; `list` inventories one closure | Strong review tool; its Python runtime may already be shared with other tools |
| `nix-tree` | Interactive dependency browsing; `--dot` exports a graph for noninteractive analysis | Prefer Nix JSON/text for routine agent work; the TUI is mainly useful to operators |
| `nix-eval-jobs` | Bounded parallel evaluation of a selected derivation set, emitting JSON lines; optional cache-status checks | Useful for larger matrices, not automatically faster for one home; workers consume memory, and JSON can contain per-job errors |
| `mcp-nixos` | Connected package/option discovery for NixOS, Home Manager and related projects | Look for callable `mcp__nixos__*` tools, including deferred tools; the server exposes tools rather than MCP resources. Verify results against locked sources |
| Nixfmt, `nixfmt-tree`, Statix, Deadnix, ShellCheck | Formatting and static checks through the runner; `nixfmt-tree` is the flake formatter | Use direct `nixfmt` for focused files; avoid repeating successful checks |
| Git and jq | Diff inspection and JSON/structured-data analysis | Prefer direct machine-readable output over adding language-specific parsing dependencies |
| age, sops, OpenSSL (operator default only) | Operator credential provisioning and recovery | Follow `secrets/README.md`; their presence does not authorize decrypting or rotating secrets |

For an existing realized closure, replace `ROOT`, `DEPENDENCY`, `OLD` and
`NEW` below with explicit `/nix/store/...` paths. A standalone home generation
is a valid root; do not assume `/run/current-system` exists on Ubuntu.

```bash
./scripts/nix-sandbox --offline path-info --json --json-format 1 --closure-size ROOT
./scripts/nix-sandbox --offline path-info --recursive --size --closure-size ROOT
./scripts/nix-sandbox --offline why-depends ROOT DEPENDENCY
nvd --color never diff OLD NEW
nix-tree --dot ROOT
```

`closureSize` is the sum of NAR sizes for unique reachable store paths, not
filesystem allocation or compressed download size. Do not sum individual package
closure sizes: dependencies overlap. To estimate removal savings, compare the
union of retained runtime paths before/after; other generations and GC roots can
still keep those paths alive. A `.drv` graph describes build dependencies and
does not measure the resulting runtime closure.

For an unbuilt output, first evaluate its exact `outPath` with the locked flake.
If that path and all its references are in a binary cache, metadata can provide a
cache-backed runtime-size estimate without downloading package contents:

```bash
nix path-info --store https://cache.nixos.org --json --json-format 1 --closure-size ROOT
```

This query uses network access, not `--offline`. Report the cache and exact path.
An uncached custom home/system output has no such metadata: inspect its selected
packages and derivation inputs, and label the result structural or incomplete.
Do not build a home/system closure to fill that gap. Likewise, a development
shell's `drvPath` or output alone is not the runtime union of its tools.

For larger evaluation reviews, `nix-eval-jobs --workers 2 --no-instantiate`
can evaluate a deliberately selected attribute set of derivations. Use its
`--select` option to map home configurations to activation packages; never
blindly recurse through all flake outputs. Inspect JSON error entries as well as
exit status. `--check-cache-status` adds availability information, not byte sizes.
Keep ordinary single-home checks on the existing test runner.

Upstream references: [nix-tree](https://github.com/utdemir/nix-tree),
[nix-eval-jobs](https://github.com/NixOS/nix-eval-jobs).

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
