# NixOS infrastructure

Flake-based NixOS and Home Manager configuration for the System76 Pangolin 14
(`pang14`). The module and inventory layout is designed to accommodate future
desktop, server, VPS, NAS, and router hosts without copying whole host
configurations or imposing laptop policy on every machine.

The flake exposes `nixosConfigurations.pang14`. Home Manager is integrated into
that system configuration, so system and user changes activate together.

For hosts not yet represented here, Ansible and dotfiles remain authoritative.
On `pang14`, Home Manager and Nixvim replace Dotbot, lazy.nvim, and Mason.

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
Starship, basic command-line utilities, Git, SSH, htop, and shared Neovim/Nixvim
with fd, ripgrep, Treesitter, completion, and ShellCheck linting. It accepts
`homeIdentity` (`fullName`, `email`, used by Git), `networkHosts`
(connection names and ports), and the pinned `inputs` as module arguments.
Shared home modules do not depend on NixOS's `osConfig`.

`development.nix` adds direnv, Codex, and Copilot.
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
Integrated Home Manager inherits `home.username` and `home.homeDirectory`
natively from the NixOS user account.
The host sets `home.stateVersion` and explicitly selects development tools; the
GNOME system role selects the workstation profile. Git is installed in the home
environment rather than relying on its presence in system packages. Account
creation, groups, authorized keys, and SSH secret provisioning remain system
responsibilities.

Standalone Ubuntu profiles are kept separately in
`lib/home-inventory.nix`. `homeConfigurations.gateway` and
`homeConfigurations.oci` select the common Bash, Git, htop, and SSH baseline,
administration tools, and the shared Nixvim profile; OCI targets AArch64.
`homeConfigurations.syntax` additionally supplies development tools, tmux with
automatic login attachment, and a persistent local SSH agent. Syntax and OCI
both select Docker shell helpers. MCP servers
are project-scoped; Grafana MCP configuration and its encrypted credential belong
to the infrastructure repository. Ubuntu's
account, groups, sudo policy, authorized keys, Nix bootstrap, and systemd linger
remain Ansible-owned.

The standalone flake constructor initializes `home.username` from the shared
user inventory and `home.homeDirectory` and `home.stateVersion` from the home
inventory. It enables weekly Home Manager generation expiry with a `-7 days`
cutoff and Nix store cleanup. Integrated Home Manager leaves this expiry service
disabled; system garbage collection remains separately managed.

Before the first standalone activation, run the host's Ansible user role. For a
Home Manager host it preserves the legacy dotfiles checkout for rollback but
removes only home paths that are still symlinks into that checkout. Build and
activate the selected generation as the user immediately afterward:

```bash
cd ~/nixos
nix build .#homeConfigurations.syntax.activationPackage
HOME_MANAGER_BACKUP_EXT=pre-home-manager ./result/activate
```

The backup extension is intended only for this one-time migration. After the
first activation, Home Manager owns those paths and installs the `home-manager`
command. Apply subsequent configuration updates explicitly from the repository:

```bash
cd ~/nixos
./apply.sh switch
```

Moving tools from Ansible's latest-release installers to Nix also moves their
updates to the inputs locked by this flake. `pang14` continues to activate Home
Manager through NixOS.

### Syntax: local-only agent in persistent tmux

`homes/syntax.nix` enables Home Manager's native `ssh-agent.service` at the user
`default.target`. An empty agent after start/restart is expected: keys load
on demand, not at service startup. No keys are created, changed, decrypted by
configuration, or copied into the Nix store.

Bash logins, tmux global/session environments and environment.d select
`$XDG_RUNTIME_DIR/ssh-agent.socket`, replacing incoming forwarding sockets.
There is no forwarding selector or fallback. Trusted-host forwarding still
forwards this **local** agent onward; shared `AddKeysToAgent yes` and normal
`ControlMaster auto`/ten-minute multiplexing remain unchanged. SSH adds a key
when it uses that key to authenticate to a destination in the shared trusted-host
block. Other destinations (including GitHub) can use the private key directly
without adding it to the agent. Encrypted keys may prompt when used.

`homes/syntax.nix` owns automatic interactive login attachment and the stable
socket's global/session hooks; `modules/home/kyleh/tmux.nix` stays portable.
Syntax's Bash socket override runs before attachment in the same block. Existing
panes retain the stable path across agent restarts; sessions with stale forwarding
environments are corrected on attachment for new panes.

Run the isolated, non-secret configuration fixtures with
`python3 -B tests/test-ssh-agent-config.py`; they evaluate generated settings
without starting an agent, reading keys, or activating services.

## Development environment

With direnv's shell hook installed:

```bash
cd ~/nixos
direnv allow    # once, if needed
codex
```

`.envrc` contains only `use flake`. Without direnv, enter `nix develop` once
before launching Codex. The default `mkShellNoCC` supplies all repository
development and operator tools: nixfmt, nixfmt-tree (`treefmt`), Statix, Deadnix,
ShellCheck, jq, ripgrep, fd, nix-eval-jobs, nix-tree, nvd, mcp-nixos, age,
sops, and OpenSSL. Use tools directly from `PATH`; routinely
missing tools belong in this shell. Outputs cover architectures in both inventories.

Git must already be available from Ubuntu or the user's Home Manager profile;
the development shell does not install it.
Nix remains host-provided and talks to the multi-user daemon. The supported
Ubuntu baseline is 26.04 LTS, with `nix-bin` and `nix-setup-systemd` installed.
Enable `nix-command` and `flakes` on the host for direct flake commands;
the test runner enables them for its own invocations.

### Codex permissions and cache

Trusted project configuration in `.codex/config.toml` selects
`nixos-development`, extending `:workspace` with network access and an explicit
allow entry for `/nix/var/nix/daemon-socket/socket`. Sandboxing stays enabled;
`/nix` is not generally writable. MCP executes `mcp-nixos` directly from `PATH`.

Codex's shell environment policy inherits the development environment and sets
`NIX_CACHE_HOME=/tmp/nixos-codex-nix-cache` and `NIX_REMOTE=daemon`.
It leaves `XDG_CACHE_HOME` unchanged; ordinary development-shell processes keep
the user's normal cache.

From the repository in an ordinary terminal, diagnose the selected profile
without building a closure:

```bash
codex sandbox -- nix --store daemon store info --json
codex sandbox -- ./test.sh --sandbox --home gateway
```

Use `-P nixos-development` to select the profile explicitly. If an existing
session retains an older policy, start a new `codex` session. Do not change
daemon socket permissions, Nix trusted users, or disable sandboxing.
See the [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).

## Normal operation

Run lightweight validation on Syntax or another development host. Full builds
and activation on `pang14` are operator steps, not agent actions. Review each
stage before proceeding.

### 1. Inspect and run lightweight checks

Use `./test.sh --sandbox SCOPE ...` inside Codex with an explicit scope (below).
Missing scope, including `--sandbox` alone, exits 2 before any checks; `--help`
does not require a scope. The runner runs linters directly from `PATH`
and uses `path:.` to include dirty and untracked files. Dirty-worktree warnings
are expected; do not stage files just to validate. Outside Codex, `--path`
includes untracked files while omitting `--sandbox` runs linter check derivations.

| Scope | Checks |
| --- | --- |
| `--lint` | Whitespace, shell syntax, Nixfmt, Statix, Deadnix and ShellCheck; no Nix invocation with `--sandbox` |
| `--home NAME` | Source checks and the selected standalone home activation `drvPath` |
| `--integrated-home HOST USER` | Source checks and only `nixosConfigurations.HOST.config.home-manager.users.USER.home.activationPackage.drvPath`, not the system toplevel |
| `--dev SYSTEM` | Source checks and all development shell `drvPath`s for the selected architecture |
| `--full` | Explicit opt-in: source checks, all-system flake evaluation without builds, and every standalone home activation `drvPath` |

`--home`, `--integrated-home` and `--dev` can be repeated and combined;
`--lint` and `--full` are exclusive of other scopes. Names must start with a
letter or underscore and contain only letters, digits, underscores or hyphens.
Standalone home and development scopes do not evaluate NixOS configurations;
integrated scopes evaluate only the selected home within NixOS. The runner collects independent failures within
a stage and skips output evaluation when source checks fail. No scope builds or
activates a system or Home Manager closure.

```bash
./test.sh --sandbox --lint
./test.sh --sandbox --home gateway --home oci
./test.sh --sandbox --home gateway --integrated-home pang14 kyleh
./test.sh --sandbox --dev x86_64-linux --dev aarch64-linux
./test.sh --sandbox --full
```

For documentation-only changes, check `git diff --check`,
`git diff --cached --check`, and referenced paths/commands. For runner changes,
also run `bash tests/test-runner.sh`; for deployment-helper changes run
`bash tests/test-apply.sh`. Run both for shared fixture/check wiring changes.
Use the
[nix-development skill](.agents/skills/nix-development/SKILL.md) to select
consumers for module changes. Reserve `--full` for shared composition, lock
changes, or uncertain evaluation boundaries.

Keep `test.sh` (scoped orchestration) separate from the two independent fixture
suites (fake-tool behavior tests). Native flake checks execute the existing
suites without real Nix, builds or activation inside the fixtures; they also
retain the existing native lints. Run fixtures directly or build just their
small check derivations for the current architecture:

```bash
bash tests/test-runner.sh
bash tests/test-apply.sh
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build --no-link --no-update-lock-file \
  "path:.#checks.$system.runner-fixtures" \
  "path:.#checks.$system.apply-fixtures"
```

`nix flake check --no-build` evaluates check derivations but does **not**
execute them. Full `nix flake check` builds checks and is broader than the
inner loop; neither form is needed for ordinary Home Manager option changes.
Selected home activation evaluations remain runner scopes, not native checks
that would build home/system closures.

For focused evaluation, select the changed non-secret option or activation
derivation directly. An integrated Home Manager check can stay narrow:

```bash
nix eval path:.#homeConfigurations.syntax.activationPackage.drvPath
nix eval path:.#nixosConfigurations.pang14.config.home-manager.users.kyleh.home.activationPackage.drvPath
```

Generated Home Manager files may have unrealized `source` paths, and
`config.home.file` keys may be absolute evaluated targets. First list the keys,
then realize only the selected source through its pure flake installable. Quote
the complete installable so the target-path attribute remains intact:

```bash
nix eval --json path:.#homeConfigurations.syntax.config.home.file \
  --apply builtins.attrNames
nix build --no-link --no-update-lock-file \
  'path:.#homeConfigurations.syntax.config.home.file."/home/kyleh/.config/tmux/tmux.conf".source'
nix eval --raw \
  'path:.#homeConfigurations.syntax.config.home.file."/home/kyleh/.config/tmux/tmux.conf".source'
```

Inspect the path printed by the final command. Run the required `test.sh` scope
as a separate command so a failed optional inspection cannot skip validation.
Avoid `builtins.getFlake` with `--expr` here; the direct installable stays pure,
honors `path:.`, and includes untracked files.

A successful evaluation does not establish runtime behavior. Report the scope
checked and any failures; if sandbox restrictions block a check, run the same
scope with `--path` outside Codex. Review the final diff before handoff.

### Review tools and closure analysis

Use the installed tools for non-building inspection:

| Tool | Useful work | Limits and trade-offs |
| --- | --- | --- |
| Nix CLI (provided by the host) | `path-info` for size/reference metadata, `why-depends` for dependency causes, `store diff-closures` for comparisons | Start with explicit store paths; runtime and derivation graphs answer different questions |
| `nvd` | Readable package/version and size deltas between two existing closures; `list` inventories one closure | Strong review tool; its Python runtime may already be shared with other tools |
| `nix-tree` | Interactive dependency browsing; `--dot` exports a graph for noninteractive analysis | Prefer Nix JSON/text for routine agent work; the TUI is mainly useful to operators |
| `nix-eval-jobs` | Bounded parallel evaluation of a selected derivation set, emitting JSON lines; optional cache-status checks | Useful for larger matrices, not automatically faster for one home; workers consume memory, and JSON can contain per-job errors |
| `mcp-nixos` | Connected package/option discovery for NixOS, Home Manager and related projects | Look for callable `mcp__nixos__*` tools, including deferred tools; the server exposes tools rather than MCP resources. Verify results against locked sources |

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

`apply.sh` detects the short hostname. On `pang14` it runs the selected
`nixos-rebuild` action for the NixOS configuration. On every other host it runs
the matching standalone `homeConfigurations.<hostname>` action; those hosts
support `build` and `switch`, but not the NixOS-only `boot` and `test` actions.

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

Commit the reviewed lock-file update separately from unrelated changes.
