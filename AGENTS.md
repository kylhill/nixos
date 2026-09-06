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
- Keep Home Manager integrated into NixOS hosts; do not introduce a separate
  activation workflow for `pang14`. Non-NixOS hosts may use standalone Home
  Manager outputs, with their OS and Nix bootstrap owned by Ansible.
- Keep shared home modules independent of `osConfig`. Pass only explicit user
  identity and network context at the platform boundary, and use Home Manager's
  own home options for paths and login names. Compose CLI, development, and
  desktop capabilities explicitly; install user-tool dependencies through Home
  Manager rather than assuming NixOS system packages exist.
- Keep standalone-home inventory separate from the inventory mapped to
  `nixosConfigurations`. Before migrating a host, coordinate ownership of
  dotfiles, packages, and user services with Ansible, including its handlers.
  Preserve mutable credentials and application state outside declarative files.

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

- After modifying repository files, run `./test.sh --sandbox` in Codex. For a
  read-only review, use narrow evaluation only where it tests a specific
  finding; do not run all linters merely because a review was requested. The
  script includes untracked files automatically, checks staged/worktree
  whitespace and shell syntax, evaluates the flake and every standalone Home
  Manager activation derivation without building them, and runs Nixfmt, Statix,
  Deadnix, and ShellCheck directly. Do not stage files just to validate.
- The sandbox mode uses a persistent daemonless store/cache under `/tmp`.
  Ordinary daemon-backed Nix commands remain unavailable on `syntax`; use an
  `./scripts/nix-sandbox` invocation for additional evaluation, adding its
  `--offline` flag when cached inputs are sufficient. Do not retry the system
  daemon socket or request escalation for daemon access.
- Validation tools may be used from their evaluated pinned `/nix/store` paths,
  from PATH (report that fallback), or fetched from the binary cache. Tool
  fetching is authorized for validation; do not stop merely because a tool is
  missing from PATH. Request network permission if input/tool downloads are
  blocked. Reuse the persistent store and locked inputs; never update
  `flake.lock` as part of validation.
- Relocated-store tool execution may require mount permissions that this
  environment cannot provide. If execution is blocked, use an already runnable
  tool when available, complete independent checks, and report the exact
  remaining check and error. Do not report skipped/failed checks as passing.
  The script exits nonzero for an incomplete run. Only hand off checks that
  actually cannot run here, using `./test.sh --path` outside Codex.
- For non-host changes, go beyond module evaluation when useful: inspect
  generated configuration, evaluate standalone Home Manager profiles and their
  activation derivations, and run focused headless or fixture-based tests in
  temporary directories. Inspect actual package dependencies and generated
  scripts. Do not execute activation scripts to test their generation.
- Narrow builds of explicitly selected formatter/linter checks, test fixtures,
  or small non-host artifacts are allowed when the environment supports them.
  Inspect their scope first; a user-module edit does not justify realizing a
  complete Home Manager environment, editor toolchain, or system closure.
  The sandbox script fetches missing tools with local and remote builds disabled.
- Never automatically build a full system/closure, VM, `nixosConfigurations`
  target, or host check. Never run `apply.sh`, `nixos-rebuild`, Home Manager
  activation, switching, or rebooting. The user owns system builds and all live
  deployment. Keep risky service/network validation read-only and provide
  narrow live-test commands and a rollback path when needed.
- Custom `homeConfigurations` outputs must be evaluated explicitly; ordinary
  `flake check` does not guarantee their traversal. `./test.sh` performs this
  evaluation. Use the narrowest meaningful additional checks for a change; do
  not repeat successful checks without a new reason.
- For Nix reviews, use an exposed `mcp-nixos` server when useful. If it is not
  available in the current session, check `codex mcp get nixos` and
  `command -v mcp-nixos`; do not enumerate unrelated MCP resources. A newly
  configured server requires a new Codex session before its tools are callable.
- Ignore expected dirty-worktree warnings, keep `nix.settings.warn-dirty = true`,
  and inspect the final diff and worktree state before handoff. Git-backed
  commands still omit new files unless staged; use `--path` while developing.

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
- Agent forwarding for the explicitly enumerated trusted hosts in
  `modules/home/kyleh/ssh.nix` is intentional. Preserve it and do not recommend
  narrowing it unless the user asks to revisit that trust policy.

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
