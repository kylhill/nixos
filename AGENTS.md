# Agent instructions

These instructions apply to the entire repository. Add a nested `AGENTS.md`
only when a subtree needs genuinely different commands or safety constraints;
keep repository-wide rules here.

## Scope and architecture

- This repository is the declarative source of truth for the `pang14` NixOS
  host. Prefer changing this repository over making imperative changes to the
  live system.
- Treat `pang14` as the first host in a future heterogeneous fleet. Preserve
  enough framework structure to support additional laptops and desktops, NAS
  and homelab servers, VPSes, and gateway routers without copying whole host
  configurations or forcing unrelated host classes through laptop-specific
  assumptions.
- `flake.nix` composes NixOS, Home Manager, Disko, sops-nix, nixos-hardware,
  and Nixvim. The primary output is `nixosConfigurations.pang14`.
- Keep host composition and hardware-specific settings in `hosts/pang14/`.
  Put reusable system configuration in `modules/nixos/`, user configuration in
  `modules/home/kyleh/`, and non-secret shared data in `lib/inventory.nix`.
- Prefer small reusable capability or role modules that hosts compose
  explicitly. Keep host identity and per-host values in inventory or the host
  subtree, and keep role-specific policy out of a universal base module. Add a
  shared abstraction when it has a credible use across multiple hosts or host
  classes; do not remove an existing useful abstraction merely because only
  `pang14` consumes it today.
- Home Manager is integrated into the NixOS configuration. Do not introduce a
  separate Home Manager activation workflow.

## Working conventions

- Inspect `git status --short` before editing. Preserve unrelated user changes,
  avoid broad mechanical rewrites, and never reset or clean the worktree.
- Read the relevant module and its imports before editing. Prefer extending an
  existing focused module over adding settings to `hosts/pang14/default.nix`.
- Keep modules small and cohesive. Use lowercase, hyphenated filenames for new
  NixOS modules and import them explicitly from the host configuration.
- Prefer structured NixOS/Home Manager options over generated config files,
  shell activation scripts, or imperative commands.
- Use `lib.mkIf` for optional configuration and assertions for assumptions that
  must hold. Keep stable, non-secret identity and network values in inventory.
- Preserve `system.stateVersion` and `home.stateVersion` unless the user
  explicitly requests and understands a state-version migration.
- Do not update `flake.lock` as a side effect of unrelated work. Use
  `./update.sh` only when input updates are requested.
- Format Nix changes with the flake formatter (`nix fmt`) or the pinned
  `nixfmt` executable. Run `git diff --check` before handing off.

## Documentation and option discovery

- Treat the versions pinned by `flake.lock` as authoritative. Before using an
  unfamiliar option, inspect its evaluated declaration or the corresponding
  module in the pinned Nixpkgs/Home Manager input. Do not assume an option from
  an online snippet exists in this release.
- Prefer, in order: evaluated option metadata, pinned source and module tests,
  the version-matched NixOS manual, then upstream project documentation. Use
  blogs, forums, and wikis only as leads and verify their claims against a
  primary source.
- Search the local source with `rg` before browsing. Useful targets include
  `nixos/modules`, `nixos/tests`, and Home Manager's `modules/` directory.
- Verify generated configuration at the narrowest useful boundary. For
  example, evaluate a specific `config` attribute or inspect a generated
  systemd unit before building the whole system.
- Do not copy configuration from the live `/etc` tree into Nix blindly.
  Separate durable user intent from generated identifiers, runtime state,
  caches, timestamps, and machine-managed files.

## Validation workflow

- After every change, run all applicable lightweight checks and linters before
  handing off. At minimum run `git diff --check`, the formatter in check mode,
  Statix, Deadnix, ShellCheck for changed shell scripts, and flake evaluation:

  ```bash
  nix flake check --no-build
  ```

- Prefer tools already available on `PATH`, but downloading a reasonable number
  of formatter, linter, or lightweight evaluation dependencies is allowed. A
  targeted `nix develop`, `nix shell`, or individual lint-check derivation is
  acceptable when needed to run the required checks. Do not run a broad
  `nix flake check` without `--no-build`, because the flake also exposes the
  full `pang14` system closure as a check. If a required tool or the Nix daemon
  is unavailable, run every remaining check and report exactly what could not
  be run.
- Never automatically perform a full system or closure build. In particular,
  do not run `nix build` on `nixosConfigurations`, the `pang14` check, a VM, or
  another target that could download or build the system package closure. This
  repository is often edited from hosts that do not have the NixOS closure
  cached. Small, explicitly targeted formatter and linter derivations are not
  considered full builds and are allowed.
- Use narrow evaluation where possible: evaluate changed options, inspect
  generated configuration or units, parse changed files, and run targeted
  linters without realizing the system closure.
- Ignore Nix's expected dirty-worktree warning while validating uncommitted
  changes. Keep `nix.settings.warn-dirty = true`; do not suppress the warning in
  configuration or treat it as a validation failure. Continue to inspect and
  report the actual worktree state before handoff.

- Git-backed flakes cannot see untracked files. While developing a new file,
  either use `nix flake check path:. --no-build` or stage only that file
  before testing. Before handoff, ensure the normal Git-backed command works if
  the new file is imported by the flake. Do not broadly stage unrelated user
  changes.
- Never run `apply.sh`, `nixos-rebuild`, Home Manager activation, or otherwise
  apply this configuration to a system. Do not use `apply.sh build` or
  `apply.sh test` as validation shortcuts. The user owns all building,
  activation, switching, and rebooting.
- For risky service changes, inspect the evaluated configuration as narrowly as
  practical and give the user commands and a rollback path for any live testing
  they choose to perform themselves.
- On `syntax`, the Codex sandbox cannot access the shared Nix daemon socket.
  Run the lightweight Nix commands allowlisted in `.codex/rules/nix.rules`
  outside the sandbox from the outset; do not first retry them inside the
  sandbox. Request permission for any other command that needs the Nix daemon
  or network rather than changing the design to bypass validation.

## Secrets and networking

- Never print, decrypt, commit, or place secret values in the Nix store.
  Secrets belong in `secrets/pang14.yaml` and are consumed through sops-nix.
- Use `sops.placeholder` plus a root-only `sops.templates` file when a service
  requires a generated environment or configuration file containing secrets.
- Keep private age identities outside the repository. Follow
  `secrets/README.md` for provisioning and recovery.
- NetworkManager owns desktop networking. Define GNOME-visible VPN profiles
  with `networking.networkmanager.ensureProfiles`; do not add parallel
  `wg-quick` management for the same connection.
- Avoid disrupting the active network connection during validation. Evaluate
  profiles only; never activate them.

## Desktop configuration

- Declare durable GNOME preferences through Home Manager `dconf.settings`.
  Do not capture transient state such as window sizes, recently opened panels,
  timestamps, app-grid positions, or cached location coordinates.
- VS Code itself is Nix-managed, but its settings and extensions are mutable so
  GitHub Settings Sync can own them. Do not add
  `programs.vscode.profiles.default.userSettings` unless the user explicitly
  wants Nix to override synced settings.
- Prefer Home Manager options for dotfiles and applications. Do not overwrite
  user-created files outside Home Manager's declared ownership.

## Storage and destructive operations

- Treat Disko and ZFS changes as high risk. Read `README.md`,
  `hosts/pang14/disko.nix`, and `scripts/install-preflight` before modifying
  storage.
- The only approved destructive installation target is:

  ```text
  /dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B97472
  ```

- The WD Blue SN580 containing Windows and Ubuntu must never be modified.
- Never run Disko destroy/format modes, repartition disks, roll back ZFS, or
  reboot automatically. Require an explicit user request and re-verify the
  exact device immediately beforehand.

## Handoff

- Summarize changed files and user-visible behavior.
- Report the exact lightweight checks and linters performed, plus anything that
  could not run. State explicitly that no full build or activation was run.
- Mention any root-only or live-system state that could not be inspected. Do
  not claim a configuration was activated when it was only evaluated or built.

## Primary references

- [OpenAI: custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
- [NixOS 26.05 manual](https://nixos.org/manual/nixos/stable/)
- [Nixpkgs contribution and formatting guidance](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md)
- [Nix reference manual: flakes](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake)
