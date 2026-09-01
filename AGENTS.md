# Agent instructions

These instructions apply to the entire repository. Add a nested `AGENTS.md`
only when a subtree needs genuinely different commands or safety constraints;
keep repository-wide rules here.

## Scope and architecture

- This repository is the declarative source of truth for the `pang14` NixOS
  host. Prefer changing this repository over making imperative changes to the
  live system.
- `flake.nix` composes NixOS, Home Manager, Disko, sops-nix, nixos-hardware,
  and Nixvim. The primary output is `nixosConfigurations.pang14`.
- Keep host composition and hardware-specific settings in `hosts/pang14/`.
  Put reusable system configuration in `modules/nixos/`, user configuration in
  `modules/home/kyleh/`, and non-secret shared data in `lib/inventory.nix`.
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

- Validate proportionally, starting with formatting and evaluation and adding a
  closure build for changes that can affect activation. For quick evaluation,
  run:

  ```bash
  nix flake check --no-build
  ```

- Git-backed flakes cannot see untracked files. While developing a new file,
  either use `nix flake check "path:$PWD" --no-build` or stage only that file
  before testing. Before handoff, ensure the normal Git-backed command works if
  the new file is imported by the flake. Do not broadly stage unrelated user
  changes.
- For changes affecting services, boot, storage, networking, secrets, or Home
  Manager activation, also build the system closure without activating it:

  ```bash
  nix build .#checks.x86_64-linux.pang14 --no-link
  ```

- Use `./apply.sh test` for an explicitly requested live test generation and
  `./apply.sh` for switch activation. A test activation changes the live system
  but not the boot default; a switch activation changes both. `./apply.sh build`
  only builds. Do not activate, reboot, or change the boot default unless the
  user asks.
- For risky service changes, inspect what activation would change when
  practical and give the user a rollback path. Use a VM test for behavior that
  can be exercised without depending on this laptop's real hardware.
- When a command needs the Nix daemon or network and fails because of the
  sandbox, request the required permission rather than changing the design to
  bypass validation.

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
- Avoid disrupting the active network connection during validation. Build and
  evaluate profiles first; activate only with explicit user approval.

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
- Report the exact validation performed and distinguish evaluation, build, test
  activation, and switch activation.
- Mention any root-only or live-system state that could not be inspected. Do
  not claim a configuration was activated when it was only evaluated or built.

## Primary references

- [OpenAI: custom instructions with AGENTS.md](https://developers.openai.com/codex/guides/agents-md)
- [NixOS 26.05 manual](https://nixos.org/manual/nixos/stable/)
- [Nixpkgs contribution and formatting guidance](https://github.com/NixOS/nixpkgs/blob/master/CONTRIBUTING.md)
- [Nix reference manual: flakes](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake)
