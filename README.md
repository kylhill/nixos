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
- `lib/inventory.nix` contains stable, non-secret host, user, network, and shared package data.
- `secrets/` contains only sops-encrypted values; `.sops.yaml` declares the age
  recipient policy. Private age identities remain outside the repository.

The `pang14` laptop intentionally uses an unencrypted ZFS pool and an
unencrypted swap partition. Data-at-rest encryption is not part of this host's
storage policy.

Contributor and coding-agent constraints live in [AGENTS.md](AGENTS.md). That
file intentionally does not duplicate the operator procedures below.

## Home Manager composition

`modules/nixos/admin-tools.nix` provides system administration tools on
`pang14`, including ethtool, gparted, ncdu, smartmontools, and wget. On
standalone Ubuntu hosts, system administration tools remain Ubuntu/Ansible-owned.

`modules/home/kyleh/default.nix` is the common CLI profile: Bash, readline,
Starship, basic command-line utilities, Git, SSH, htop, and shared Neovim/Nixvim
with fd, ripgrep, Treesitter, completion, and ShellCheck linting. It accepts
`homeIdentity` (`fullName`, `email`, used by Git), `networkHosts`
(connection names and ports), and the pinned `inputs` as module arguments.
Shared home modules do not depend on NixOS's `osConfig`.

`ubuntu.nix` is explicitly selected by all four standalone homes. It retains
Home Manager's Bash, Git, readline, and less configuration while using Ubuntu's
Bash, Git, less, and man executables (`package = null`). Manual-page support
remains enabled. It restricts the Nix glibc locale archive to `en_US.UTF-8`;
`pang14` restricts its system locales to the same locale, and integrated Home
Manager inherits the system locale package natively. The Ubuntu profile disables
Home Manager's XDG MIME integration; native NixOS homes retain it.
`systemctl` Bash completion comes from the host's systemd package: NixOS
exposes it through the system profile, and Ubuntu ships it under `/usr/share`.

`development.nix` adds direnv, fzf, bat, fd, ripgrep, and GitHub CLI; `ai.nix` adds Codex,
Copilot, and MCP tools.
`workstation.nix` adds graphical applications, GNOME preferences, and Bash VTE
integration.
NixOS and all homes use the locked stable `nixpkgs` package set. Integrated
Home Manager shares the system package set through `useGlobalPkgs`. An explicit
`unstablePkgs` argument supplies the freshness exceptions: Codex, Copilot CLI,
Grafana MCP, NixOS MCP, and VS Code. The `mcp-nixos` flake app also uses unstable.
Nixvim follows its matching stable release branch. Neovim and its plugins,
Firefox, Python, and the other home tools use stable;
the separately pinned Solarized plugin source remains independent of that choice.
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
the Ubuntu boundary, and the shared Nixvim profile; OCI targets AArch64.
`homeConfigurations.wsl` adds direnv to that x86_64 baseline.
`homeConfigurations.syntax` additionally supplies direnv, AI tools, tmux with
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

### WSL bootstrap

To update all upgradeable installed WinGet packages, the WSL runtime, and Ubuntu
packages later, run this from an elevated PowerShell prompt:

```powershell
.\windows\update.ps1
```

The update runs without prompts and reports failures from each step. It upgrades
Ubuntu packages with `apt-get full-upgrade`; it does not change the Ubuntu release
or activate a new Home Manager generation. Use `-Distro NAME` if the installed
Ubuntu distribution has a different WSL name.

From an elevated PowerShell prompt in a checkout of this repository, run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\windows\bootstrap.ps1
```

When `-Profile` is omitted, the script prompts for `Home` or `Work`. For an
unattended or repeatable invocation, select it explicitly:

```powershell
.\windows\bootstrap.ps1 -Profile Home
.\windows\bootstrap.ps1 -Profile Work
.\windows\bootstrap.ps1 -Profile Home -Verify
.\windows\bootstrap.ps1 -Profile Home -WindowsOnly -Verify
.\windows\verify.ps1 -Scope Configuration
.\windows\verify.ps1 -Scope Packages -Profile Home
.\windows\verify.ps1 -Profile Work
```

The top-level script applies the shared native state in
`windows/configuration.winget`, the applications in
`windows/packages-common.winget`, and the selected `packages-home.winget` or
`packages-work.winget`. The Home profile adds Deluge, Nextcloud, Steam, and WireGuard;
the Work profile adds Google Drive. Package profiles are additive: selecting a
different profile later does not uninstall packages installed by an earlier
profile.

`-Verify` tests all three applied manifests after Windows configuration and before
WSL setup. `-WindowsOnly` skips WSL setup. For verification without applying
configuration, enabling WinGet configuration, provisioning SSH, or running WSL,
use `windows/verify.ps1`. Its `-Scope` selects `Configuration`, `Packages`, or
`All` (the default). Package verification requires `-Profile Home` or `Work`;
a configuration-only test does not require a profile. Both scripts report elapsed
time per manifest.

Bootstrap leaves the WSL runtime version alone; use `windows/update.ps1` for
updates. `bootstrap-wsl.ps1` owns WSL installation and the Linux bootstrap
handoff. Running it directly follows the same fresh-install pause and mounted
script invocation as the top-level bootstrap; `-Distro NAME` selects a different
WSL distribution name.
Windows Terminal replaces `settings.json` with the declared settings and
profiles, removing existing entries outside this repository's configuration.
Its first edit keeps a `settings.json.pre-dsc.bak` copy of the prior file.

The script then sets up Ubuntu WSL2 and runs `scripts/bootstrap-home.sh` inside Ubuntu. On a
fresh install it stops after installing WSL: reboot if requested, launch Ubuntu
once to create the `kyleh` Linux user, then rerun the same command. It is safe
to rerun after a partial install. The Linux bootstrap installs Git inside
Ubuntu and clones this public repository there; native Windows Git is not
required. It requires an x86_64 WSL client
and selects
`homeConfigurations.wsl`, installs Ubuntu's `nix-bin` and
`nix-setup-systemd` packages, validates the flake target, and activates the
Home Manager generation from the repository's locked inputs. If systemd is not
running, it stops with the required `/etc/wsl.conf` and PowerShell restart
instructions. Flakes are enabled for the bootstrap process through `NIX_CONFIG`,
which is explicitly passed to the refreshed user processes; bootstrap does not
write a user `nix.conf`. Later, `apply.sh` supplies the required feature settings.

The DSC documents own native Windows packages, policies, fonts, and Terminal
settings. Registry state is grouped into separate machine-wide and current-user
script resources to avoid the per-resource startup cost of evaluating every
value independently; each desired value remains an individually documented
entry and only mismatches are written. The Windows (dark) theme and No Sounds
scheme are initialized once per user; later changes in Windows Settings are not
reset by another configuration run. No full Windows apply has been run from
this Linux checkout. Test the
configuration on one Windows 11 Pro machine before rolling it out to the other
two. Supported-policy gaps are intentional: Settings Agent and File Explorer
AI Actions have no verified Pro policy here; neither has an undocumented
registry workaround. Edge Secure Network, Office surveys/feedback controls,
taskbar End Task, and some shell/lock-screen promotions are not forced until
a current supported mechanism is verified for this baseline. Some Edge for
Business policies only affect applicable work profiles. TVRename remains a
manual install unless a reliable WinGet package is identified.

Windows bootstrap prompts without echo for an optional SOPS age secret key. It
installs the Windows OpenSSH client config from `windows/ssh-config` at
`%USERPROFILE%\.ssh\config`, creates `config.d` for drop-ins, and saves an existing
config once as `config.pre-bootstrap.bak` before replacing it. It then
decrypts the shared SSH identity in a restricted temporary Windows directory,
adds it to the OpenSSH agent configured by DSC, then removes the temporary
private key. Standalone SSH provisioning requires the agent to be running with
Automatic startup; apply `windows/configuration.winget` first. Leaving the prompt
blank skips loading the key. The WSL home starts
`wsl2-ssh-agent` as a user service and exposes its socket through `SSH_AUTH_SOCK`;
WSL does not receive a private key file. Check `ssh-add -l` in PowerShell and a
new WSL shell after bootstrap. If an older bootstrap created
`~/.ssh/id_ed25519` in WSL, remove that legacy file after confirming the Windows
agent contains the key.

On WSL, `./apply.sh switch` always selects the generic `wsl` home rather than
the Windows-derived hostname. Update locked inputs separately with
`./update.sh` (or `./update.sh INPUT` for a selected input); ordinary bootstrap
and activation do not update them.

Moving tools from Ansible's latest-release installers to Nix also moves their
updates to the inputs locked by this flake. `pang14` continues to activate Home
Manager through NixOS.

### Syntax: local-only agent in persistent tmux

`homes/syntax.nix` enables Home Manager's native `ssh-agent.service` at the user
`default.target`. An empty agent after start/restart is expected: keys load
on demand, not at service startup. SOPS provisions the existing keys as described
below; it does not load it into the agent or copy plaintext into the Nix store.

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

Inspect the non-secret generated agent settings through the lightweight option
scopes below. Verify key loading and socket behavior on the live host separately;
evaluation does not start the agent or establish runtime behavior.

### SSH key provisioning

`secrets/home.yaml` contains the shared encrypted SSH private/public key pair.
Syntax and pang14 provision it declaratively at `~/.ssh/id_ed25519` (mode `0600`)
and `~/.ssh/id_ed25519.pub` (mode `0644`). Windows bootstrap loads the key into
the Windows OpenSSH agent; WSL uses that agent through a socket bridge. OCI and
gateway do not provision either file. Trusted-host forwarding remains unchanged.

`secrets/syntax.yaml` contains the encrypted Ubiquiti key pair and has only the
operator age recipient. Syntax alone provisions `~/.ssh/ubnt-20220508` (mode
`0600`) and `~/.ssh/ubnt-20220508.pub` (mode `0644`); pang14, OCI, gateway, and WSL
do not. The existing network-device SSH configuration continues to use that path.

Syntax uses Home Manager's `sops-nix` user service at login and activation.
Its existing operator age identity must be installed separately at
`~/.config/sops/age/keys.txt` with mode `0600`. Windows bootstrap prompts for an
operator age identity and discards it after loading the agent. Pang14 keeps
system-level provisioning, using its existing `/var/lib/sops-nix/key.txt`
identity and user-owned secret files. Both recipients
are declared in `.sops.yaml`; private age identities stay outside the repository
and are not bootstrapped from the SSH key being provisioned.

Before activation, preserve any different existing key pair outside these
managed paths: SOPS replaces the paths with symlinks to runtime secrets.
On standalone Syntax, Ansible must leave these key pairs and its age identity
unmanaged while retaining ownership of account setup and authorized keys.
Ansible-managed systemd linger keeps Syntax's user services available without
an interactive login. Key passphrases, if present, remain unchanged.

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
ShellCheck, jq, ripgrep, fd, PowerShell, nix-eval-jobs, nix-tree, nvd, age,
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

Use the [nix-development skill](.agents/skills/nix-development/SKILL.md) to
select the validation loop and representative consumers for each change.
Run `./test.sh --sandbox SCOPE ...` inside Codex with an explicit scope.
Missing scope exits 2 before any checks; `--help` needs no scope. Sandbox mode
uses tools directly from `PATH` and evaluates `path:.`, including dirty and
untracked files. Dirty warnings are expected; do not stage files to validate.
Outside Codex, `--path` is a flag with no argument, selecting the same flake
reference: `./test.sh --path --home syntax`. Without `--sandbox`, source and
fixture checks build their small native check derivations.

| Scope | Checks |
| --- | --- |
| `--lint` | Whitespace, shell syntax, Nixfmt, Statix, Deadnix and ShellCheck; no Nix invocation in sandbox mode |
| `--fixtures SUITE` | Source checks and `runner`, `apply`, `windows`, or `all` fixtures |
| `--home NAME` | Source checks and selected standalone home activation `drvPath` |
| `--integrated-home HOST USER` | Source checks and selected integrated home activation `drvPath`, without evaluating the system toplevel |
| `--system HOST` | Source checks and system assertions; fails with assertion messages, without a system build |
| `--dev SYSTEM` | Source checks and all development shell `drvPath`s for the architecture |
| `--option-home NAME OPTION` | One non-secret standalone home `config.OPTION`, without source checks |
| `--option-integrated-home HOST USER OPTION` | One non-secret integrated home `OPTION`, without source checks |
| `--option-system HOST OPTION` | One non-secret NixOS `config.OPTION`, without source checks |
| `--full` | Source checks, all-system flake evaluation without builds, and every standalone home activation `drvPath` |
| `--ci` | Full validation and all fixture suites |

Home, integrated-home, system and development scopes are repeatable and
combinable. Fixture selection is repeatable, deduplicated, and combines with
selected scopes, lint, or full evaluation. Lint/full/CI cannot combine with
selected output scopes. Option scopes are exclusive and print JSON; names and
dotted option components must start with a letter or underscore and contain
only letters, digits, underscores or hyphens. Use option scopes only for
non-secret values: terminal output and logs are visible.

The runner collects independent failures. Failed source checks suppress output
evaluation; selected fixtures still run, and a fixture/output failure does not
suppress other fixtures. No scope builds or activates a home/system closure.
System assertions check configuration assumptions, not every service definition
or runtime state; inspect affected options/generated files as well.

```bash
# Iterate on the changed option, then batch the affected completion contexts.
./test.sh --sandbox --option-home syntax programs.git.enable
./test.sh --sandbox --home gateway --home oci --integrated-home pang14 kyleh
./test.sh --sandbox --option-system pang14 services.openssh.enable
./test.sh --sandbox --system pang14

# Script changes need no home/system evaluation.
./test.sh --sandbox --fixtures runner
./test.sh --sandbox --fixtures apply
./test.sh --sandbox --fixtures windows
./test.sh --sandbox --fixtures all --dev x86_64-linux --dev aarch64-linux

# Shared composition and input updates.
./test.sh --sandbox --full
./test.sh --sandbox --ci
```

Documentation-only completion uses `git diff --check`,
`git diff --cached --check`, and referenced paths/commands. For skill metadata,
use the skill-creator validator when available. No Nix evaluation is required
solely for documentation changes.

`test.sh` orchestrates independently executable fixture suites. Runner/apply
fixtures use fake tools, isolated temporary directories, and no real builds or
activation. Windows fixtures use `pwsh -NoLogo -NoProfile`, parse every Windows
script, and mock WinGet/WSL for verification/update behavior. They neither need
administrator privileges nor change Windows state. The shell wrapper also
isolates PowerShell startup cache/config/data in a temporary directory. Other
provisioning paths receive parser coverage; real DSC, credentials and WSL
behavior remain Windows operator checks. Run a suite directly during iteration:

```bash
bash tests/test-runner.sh
bash tests/test-apply.sh
bash tests/test-windows.sh
```

The shell-file manifest in `tests/shell-files` is shared by direct syntax/lint,
native ShellCheck, and runner-fixture setup; add new shell scripts there. Native
checks use filtered source inputs: Nix linters receive Nix files, ShellCheck and
runner fixtures receive the manifest's files, apply fixtures receive their own
script/helper, and Windows fixtures receive Windows files and their suite.
Documentation-only edits therefore preserve check derivations. Check-input
changes should be validated by evaluating affected check derivations and building
only the small checks for the current architecture:

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build --no-link --no-update-lock-file \
  "path:.#checks.$system.runner-fixtures" \
  "path:.#checks.$system.apply-fixtures" \
  "path:.#checks.$system.windows-fixtures"
```

`nix flake check --no-build` evaluates check derivations without executing them.
Full `nix flake check` builds checks and is broader than the ordinary loop.
Selected home activation evaluations remain runner scopes, not native checks
that build home/system closures.

For options with quoted or unusual attribute keys, select a direct quoted Nix
installable with `--no-update-lock-file`. System assertions are also available
through `--option-system HOST assertions` for inspecting records; `--system`
checks their truth values and fails on false assertions.

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

`apply.sh` detects the short hostname and WSL. On the `pang14` NixOS host it
runs the selected `nixos-rebuild` action. On WSL it selects the standalone
`homeConfigurations.wsl` home even when the hostname is `pang14`. Other hosts
select the standalone home matching their hostname. Standalone homes support
`build` and `switch`, but not the NixOS-only `boot` and `test` actions.

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

### ZFS backup scheduling

On `pang14`, Sanoid checks `rpool/home` for due snapshots hourly at `:00`;
Syncoid replicates them to Syntax at `:15`. Both timers are persistent, so a
missed schedule triggers a catch-up run when the timer becomes active again.
Syncoid requires a successful Sanoid one-shot run before replication, including
during catch-up, because it uses `--no-sync-snap`. Snapshot retention is unchanged.
Catch-up can add startup I/O and still requires the remote host to be reachable;
a failed replication waits for the next scheduled run.

### Updating pinned inputs

Treat an input update like any other change: update without activation, review
the lock-file diff, and then run the complete progression above:

```bash
./update.sh
git diff -- flake.lock
```

Commit the reviewed lock-file update separately from unrelated changes.
