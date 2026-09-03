# Agent instructions

These instructions apply to the entire repository. They supplement the operator
workflows in `README.md` and the credential procedures in `secrets/README.md`;
do not duplicate those documents here. Add a nested `AGENTS.md` only when a
subtree needs genuinely different commands or safety constraints.

## Scope and architecture

- This repository is the declarative source of truth for the `pang14` NixOS
  host. Prefer changing this repository over making imperative changes to the
  live system.
- Treat `pang14` as the first host in a future heterogeneous fleet. Do not copy
  whole host configurations or force unrelated host classes through
  laptop-specific assumptions.
- `flake.nix` composes NixOS, Home Manager, Disko, sops-nix, nixos-hardware,
  Nixvim, and nix-index-database. The primary output is
  `nixosConfigurations.pang14`.
- Keep host composition and hardware-specific settings in `hosts/pang14/`.
  Put reusable system configuration in `modules/nixos/`, user configuration in
  `modules/home/kyleh/`, and non-secret shared data in `lib/inventory.nix`.
- Prefer small capability or role modules that hosts compose explicitly. Keep
  identity and per-host values in inventory or the host subtree, and keep
  role-specific policy out of the universal base. Introduce an abstraction only
  for credible reuse, but do not remove a useful existing abstraction solely
  because it currently has one consumer.
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
- Keep documentation operational: commands must match repository scripts and
  facts must be traceable to evaluated configuration. Put operator workflows in
  `README.md`, secrets lifecycle material in `secrets/README.md`, and agent-only
  constraints here.

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

- Codex sessions on `syntax` cannot access the system Nix daemon Unix socket,
  including after entering `nix develop` or requesting command escalation. Do
  not run ordinary store-backed commands such as `nix develop`, `nix build`,
  `nix eval`, `nix shell`, or `./test.sh` in the sandbox. Repeated socket retries
  and approval requests do not add useful validation.
- Use the repository's daemonless evaluation script instead. It gives Nix a
  persistent user-owned local store and fetcher cache under `/tmp`, evaluates
  every flake output with `--no-build`, and never contacts the system daemon:

  ```bash
  git diff --check
  ./sandbox-test.sh
  bash -n path/to/changed-script
  shellcheck path/to/changed-script
  ```

- The first daemonless evaluation may need approval to fetch locked inputs from
  GitHub and `cache.nixos.org`; request network permission for the script when
  the sandbox blocks those domains. Reuse its `/tmp` store rather than creating
  a fresh store per command. Use `./sandbox-test.sh --path` when an imported
  untracked file must be visible to the flake.
- The daemonless script validates the module graph, option types, assertions,
  package references, and flake outputs. It cannot build the formatting,
  Statix, Deadnix, or ShellCheck derivations: local chroot-store builders cannot
  write their logical `/nix/store` outputs through this sandbox. Run `bash -n`
  and ShellCheck directly for each changed shell script. If `nixfmt`, Statix,
  or Deadnix already exists on `PATH`, run it directly; do not use Nix to obtain
  a missing tool. Otherwise, ask the user to run `./test.sh` outside Codex and
  report those derivation builds as required user-side validation.
- Never automatically perform a full system or closure build. In particular,
  do not run `nix build` on `nixosConfigurations`, the `pang14` check, a VM, or
  another target that could download or build the system package closure. This
  repository is often edited from hosts that do not have the NixOS closure
  cached. The user-side `./test.sh` command builds only explicitly targeted
  formatter and linter derivations, which are not considered full builds.
- When suggesting additional user-side validation, prefer narrow evaluation of
  changed options or generated units over realizing the system closure.
- Ignore Nix's expected dirty-worktree warning while validating uncommitted
  changes. Keep `nix.settings.warn-dirty = true`; do not suppress the warning in
  configuration or treat it as a validation failure. Continue to inspect and
  report the actual worktree state before handoff.

- Git-backed flakes omit untracked files. Use `./sandbox-test.sh --path` while
  developing a new imported file; do not stage files merely to validate them
  and never broadly stage unrelated changes. Before handoff, remind the user to
  stage the new file before running the normal Git-backed `./test.sh`.
- Never run `apply.sh`, `nixos-rebuild`, Home Manager activation, or otherwise
  apply this configuration to a system. Do not use `apply.sh build` or
  `apply.sh test` as validation shortcuts. The user owns all building,
  activation, switching, and rebooting.
- For risky service changes, inspect the evaluated configuration as narrowly as
  practical and give the user commands and a rollback path for any live testing
  they choose to perform themselves.

## Secrets and networking

- Never print, decrypt, commit, or place secret values in the Nix store.
  Secrets belong in `secrets/pang14.yaml` and are consumed through sops-nix.
- Reading encrypted files or recipient metadata is safe; commands that decrypt,
  edit, rekey, or display secret values require an explicit user request.
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
- `pang14` intentionally enables `boot.zfs.forceImportRoot` so its exclusively
  owned root pool can recover automatically after an unclean shutdown. Preserve
  this policy and do not recommend disabling it unless the user asks to revisit
  the tradeoff.
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

## Reference hierarchy

- For repository behavior, prefer evaluated pinned options and sources over web
  examples. Primary external references are the [NixOS 26.05
  manual](https://nixos.org/manual/nixos/stable/), [Nix
  manual](https://nix.dev/manual/nix/latest/), and upstream documentation for
  the relevant pinned input.
- For instruction discovery and scope, follow [OpenAI's AGENTS.md
  guidance](https://developers.openai.com/codex/guides/agents-md). Keep this
  root file concise; use nested instructions only for genuinely local rules.
