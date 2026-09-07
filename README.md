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

- `flake.nix` pins dependencies and constructs the NixOS hosts in
  `lib/inventory.nix` and standalone homes in `lib/home-inventory.nix`.
- `hosts/pang14/` selects capabilities and owns hardware, boot, storage, and
  host-specific policy.
- `modules/nixos/` contains reusable system capabilities and roles.
- `modules/home/kyleh/` contains portable Home Manager capabilities.
- `lib/inventory.nix` contains stable, non-secret host, user, and network data.
- `secrets/` contains only sops-encrypted values; `.sops.yaml` declares the age
  recipient policy. Private age identities remain outside the repository.

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

`development.nix` adds full Nixvim and its supporting fd, fzf, ripgrep, and
lazygit tools, plus direnv, GitHub CLI, Codex, Copilot, and MCP integration.
`workstation.nix` adds graphical applications, GNOME preferences, and Bash VTE
integration.
Both profiles also accept `latestPkgs`, an explicitly configured package set
from the locked `nixpkgs-unstable` input: development uses it for Codex and
Copilot, while the workstation uses it for Firefox and VS Code.
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
shell helpers, Bubblewrap, and Socat for the AI command-line tools. MCP servers
are project-scoped: this repository's Codex configuration invokes its pinned
mcp-nixos package through `nix run path:.#mcp-nixos`. Grafana MCP configuration
and its encrypted credential belong to the infrastructure repository. Ubuntu's
account, groups, sudo policy, authorized keys, Nix bootstrap, and systemd linger
remain Ansible-owned.

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
| Shared Home Manager option | Evaluate the changed option or generated file in one representative consumer | Evaluate one activation derivation per distinct platform or module context; use the narrow integrated-home command below when applicable |
| Home/NixOS module composition | Evaluate affected options while editing | `./test.sh --sandbox --full` when imports, arguments, overlays, package sets, or cross-module wiring change |
| Development shell/package | Evaluate the selected output | `./test.sh --sandbox --dev x86_64-linux`, plus a small targeted build if useful |
| Lock file/shared flake composition | Narrow checks while editing | `./test.sh --sandbox --full` |

`--home` and `--dev` are repeatable and can be combined. For example:

```bash
./test.sh --sandbox --home gateway --home oci
./test.sh --sandbox --dev x86_64-linux --dev aarch64-linux
```

Selected homes evaluate only their activation derivations; selected development
systems evaluate all their development-shell derivations. Neither evaluates a
NixOS configuration. In sandbox mode, `--lint` runs source checks only and does
not invoke Nix. No scope builds or activates a host or Home Manager environment.

A shared Home Manager module does not require `--full` merely because NixOS also
integrates it. For an option-only change with no platform branch, evaluate one
standalone activation derivation and the integrated home activation derivation:

```bash
./test.sh --sandbox --home syntax
nix eval \
  path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh.home.activationPackage.drvPath
```

Add consumers only when they exercise a distinct architecture, conditional,
package set, module argument, or integration path. Use `--full` for composition
changes or when a narrow evaluation cannot establish the affected boundary.

The default remains `--full`: lint, all-system flake evaluation without builds,
and explicit evaluation of every standalone home activation derivation.
`flake check` alone does not traverse custom `homeConfigurations`.

Sandbox mode includes untracked files and runs the linters supplied by the agent
development shell directly. Launch Codex with `./agent` from the repository root;
lint-only runs do not invoke Nix.

Codex's managed sandbox makes the normal user cache read-only. The Codex-only
`agent` development shell sets `XDG_CACHE_HOME` to
`${TMPDIR:-/tmp}/nixos-codex-nix-${UID}/cache` and enables the required Nix CLI
features, so direct `nix` and `nix-store` commands are safe when Codex is launched
through `./agent`. The default operator shell keeps the normal user cache. Daemon
access failures are returned directly.

For mount restrictions, use runnable tools or run the same scope with `--path`
outside Codex. Failed or unavailable checks exit nonzero.

Additional Nix commands can be run directly inside that agent environment:

```bash
nix eval path:.#homeConfigurations.syntax.activationPackage.drvPath
```

To realize an explicit store path with the legacy store command (for example, a
pinned source archive needed for inspection), use the British-spelled option:

```bash
nix-store --realise /nix/store/EXPLICIT-PATH
```

`nix store realise` is not available in the supported Nix CLI. Realizing a
source path is a narrow artifact fetch; it is not authorization to build a full
system or Home Manager closure.

The repository's `.codex/config.toml` selects the `nixos-development` permission
profile with network access enabled. This profile permits the daemon socket;
a conversation started with a different effective policy can still reject it
with `Operation not permitted`. From an ordinary terminal, verify the profile
without building anything:

```bash
codex sandbox -P nixos-development -- nix --store daemon store info --json
codex sandbox -P nixos-development -- ./test.sh --sandbox --home gateway
```

Start a new Codex session using that repository profile if the current session
retains a restrictive policy. Do not broaden filesystem permissions on the
daemon socket, change Nix trusted users, or disable sandboxing to fix this.
If a session was not launched with `./agent`, restart it rather than allowing Nix
to use the read-only normal user cache.

Outside Codex, omit `--sandbox` to run formatter and linter check derivations
through Nix before the selected output evaluations. Use `--path` to include
untracked files.

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

After changing to the repository root, launch Codex through the pinned agent
environment so every session has the expected linters and review tools on
`PATH`:

```bash
./agent
```

The launcher forwards arguments to Codex and is equivalent to
`nix develop path:.#agent --command codex`. For example, use `./agent --help`
to show the Codex command-line help without starting an interactive session.

Inside that Codex session, use `./test.sh --sandbox` with the scope appropriate
to the change. From an ordinary shell, run a one-off check in the same pinned
environment with, for example:

```bash
nix develop path:.#agent --command ./test.sh --path --lint
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
and OpenSSL for encrypted-secret maintenance. Shells, apps and development
checks are exposed for architectures present in either host inventory,
including AArch64 standalone homes.

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
first and reuse available executables. For lint-only work inside Codex, use
`./test.sh --sandbox --lint`; it runs the agent-shell linters directly.

| Tool | Useful work | Limits and trade-offs |
| --- | --- | --- |
| Nix CLI (provided by the host) | `path-info` for size/reference metadata, `why-depends` for dependency causes, `store diff-closures` for comparisons | Start with explicit store paths; runtime and derivation graphs answer different questions |
| `nvd` | Readable package/version and size deltas between two existing closures; `list` inventories one closure | Strong review tool; its Python runtime may already be shared with other tools |
| `nix-tree` | Interactive dependency browsing; `--dot` exports a graph for noninteractive analysis | Prefer Nix JSON/text for routine agent work; the TUI is mainly useful to operators |
| `nix-eval-jobs` | Bounded parallel evaluation of a selected derivation set, emitting JSON lines; optional cache-status checks | Useful for larger matrices, not automatically faster for one home; workers consume memory, and JSON can contain per-job errors |
| `mcp-nixos` | Connected package/option discovery for NixOS, Home Manager and related projects | Look for callable `mcp__nixos__*` tools, including deferred tools; the server exposes tools rather than MCP resources. Verify results against locked sources |
| Nixfmt, `nixfmt-tree`, Statix, Deadnix, ShellCheck | Formatting and static checks through the runner; `nixfmt-tree` is the flake formatter | Use direct `nixfmt` for focused files; avoid repeating successful checks |
| Git and jq | Diff inspection and JSON/structured-data analysis | Prefer direct machine-readable output over adding language-specific parsing dependencies |
| age, sops, OpenSSL (operator default only) | Operator encrypted-secret maintenance and recovery | Private identities stay outside the repository; their presence does not authorize decrypting or rotating secrets |

For an existing realized closure, replace `ROOT`, `DEPENDENCY`, `OLD` and
`NEW` below with explicit `/nix/store/...` paths. A standalone home generation
is a valid root; do not assume `/run/current-system` exists on Ubuntu.

```bash
nix path-info --json --json-format 1 --closure-size ROOT
nix path-info --recursive --size --closure-size ROOT
nix why-depends ROOT DEPENDENCY
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

This query uses network access. Report the cache and exact path.
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
