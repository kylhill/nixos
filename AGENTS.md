# Agent instructions

## Development

- Inspect `git status --short` before editing and the final diff before handoff.
  Preserve unrelated changes; never reset or clean the worktree.
- Read the relevant module and imports first. Put host composition/hardware in
  `hosts/pang14/`, reusable system capabilities in `modules/nixos/`, portable
  user configuration in `modules/home/kyleh/`, and non-secret shared values in
  `lib/inventory.nix`. Standalone homes use `lib/home-inventory.nix` separately.
- Extend focused modules; compose capabilities explicitly rather than copying
  hosts or putting role policy in the universal base. Use lowercase, hyphenated
  NixOS module filenames. Add abstractions for credible reuse.
- Prefer structured NixOS/Home Manager options over generated files or shell
  activation scripts. Use `lib.mkIf` for optional configuration and assertions
  for required assumptions.
- Keep shared home modules independent of `osConfig`; pass explicit identity
  and network context, use Home Manager's home options for paths/usernames, and
  install user-tool dependencies through Home Manager.
- Preserve both `stateVersion` values. Change `flake.lock` only for requested
  input updates, using `./update.sh`.
- For unfamiliar options, search evaluated declarations or pinned input source
  with `rg` first. `flake.lock` is authoritative; verify external examples
  against pinned sources or version-matched upstream documentation.
- Launch with `cd ~/nixos` then `codex`. Direnv loads the default development
  shell, with all normal repository tools on `PATH`. Use those tools directly;
  do not recursively invoke `nix develop` or `nix-shell` merely to obtain tools. A routinely
  required tool that is absent belongs in the default development shell.
- For tool selection and closure commands, see
  [README.md](README.md#review-tools-and-closure-analysis).
- For Nix questions, inspect the callable tool inventory, including deferred
  tools, for `mcp__nixos__*`. Do not infer that mcp-nixos is unavailable from
  `list_mcp_resources` or `list_mcp_resource_templates`; it exposes tools rather
  than resources. When `mcp__nixos__nix` is available, use it as directed and
  verify repository-specific claims against evaluation or pinned source.

## Validation

- Match checks to the change. Use the `nix-development` skill to select consumers
  and inspect generated configuration; use README's lightweight-check section
  for commands and scope mechanics. Do not stage files just to validate.
- Select affected contexts and checks up front, with one validation owner to
  avoid duplicate runs. Establish a baseline when relevant to the change.
  Iterate narrowly, then batch repository-wide completion lint and selected
  context checks; rerun successful checks only when their relevant inputs change.
- Use `./test.sh --sandbox SCOPE ...` with an explicit scope for repository checks and `path:.` when evaluation
  must include untracked files. See README for Codex permission/cache diagnostics.
- Complete independent checks when one check is blocked, and report the exact
  failure plus an outside-Codex handoff command when needed.
- Add narrow evaluations, generated-config inspections, or small fixture builds
  when they test the change. Read-only reviews need only checks that substantiate
  findings. Do not repeat successful checks without a new reason.
- Never build full system/Home Manager closures, VMs, `nixosConfigurations`
  targets, or host checks. Never run `apply.sh`, `nixos-rebuild`, activation,
  switching, or rebooting; the user owns full builds and live deployment.
- At handoff, summarize changes, checks and limitations; explicitly state that
  no full build or activation ran. Distinguish evaluated behavior from live
  behavior and identify relevant live/root-only state that could not be checked.

## Preserve intentional policy

- Keep Home Manager integrated into NixOS. For standalone-home migrations,
  follow `README.md` and coordinate dotfile/package/service ownership and handlers
  with Ansible; preserve mutable credentials and application state.
- NetworkManager owns desktop networking and VPNs through
  `networking.networkmanager.ensureProfiles`; do not add parallel `wg-quick`
  management. Evaluate profiles without activating or disrupting connections.
- Preserve trusted-host SSH agent forwarding in `modules/home/kyleh/ssh.nix`
  and `pang14`'s `boot.zfs.forceImportRoot` unless asked to revisit those policies.
- Declare durable GNOME preferences through `dconf.settings`, excluding runtime
  state. VS Code settings/extensions belong to GitHub Settings Sync; do not add
  `userSettings` without a request to override Sync. Respect dotfile ownership.
- Keep `nix.settings.warn-dirty = true`; dirty-worktree warnings are expected.

## Temporary files and caches

- Create agent-owned scratch directories with `mktemp -d`. Install an EXIT
  cleanup trap immediately in the same shell invocation, and finish scratch work
  within that invocation. Keep downloads, extracted sources, and fixture
  home/config directories inside it; avoid loose files or predictable paths in
  `/tmp`. Clean up only the exact directory created by that invocation.
- Keep intentional cross-command artifacts in the agent's session directory
  outside the repository, not ad hoc `/tmp` directories. Remove disposable
  artifacts when finished; report leftovers if interruption prevents cleanup.
- Reuse configured caches; do not create a new Nix cache per command or treat
  shared caches as scratch. Cache relocation requires checking sandbox access
  and updating the configuration and README together; prefer a stable,
  user-owned cache location when supported.
- Do not blanket-delete `/tmp`, `nix-shell.*`, or agent caches. Cleanup outside
  task-owned scratch requires an explicit request and checking ownership and
  active use; age or a temporary-looking name alone does not establish safety.

## Secrets and storage

- Keep values sops-encrypted under `secrets/` and private age identities outside
  the repo. Never expose plaintext in Git, logs, chat, or the Nix store.
  Decrypting, editing, or rekeying secrets requires an explicit request;
  encrypted files/recipient metadata are safe to inspect. Use `sops.placeholder`
  and root-only `sops.templates` for system service files containing secrets.
- Never automatically format, repartition, or roll back ZFS. Destructive operations
  require an explicit request and immediate device verification.

Keep operator procedures in `README.md` and agent constraints here. If secrets
procedures are added, place them in `secrets/README.md`. Avoid duplicating docs;
add nested instructions only for different local commands or safety rules.
