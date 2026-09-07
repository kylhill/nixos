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
- Use tools from the `agent` development shell for repository work; the ambient
  direnv shell is the operator environment. Prefer the scoped test runner, or
  run an individual missing tool with
  `nix develop path:.#agent --command TOOL ...`.
- For tool selection and closure reviews, see README's "Review tools and closure
  analysis": `nvd`, `nix-tree`, `nix-eval-jobs`, and MCP have different
  roles. Prefer existing executables and machine-readable, non-building checks.
- For Nix questions, inspect the callable tool inventory, including deferred
  tools, for `mcp__nixos__*`. Do not infer that mcp-nixos is unavailable from
  `list_mcp_resources` or `list_mcp_resource_templates`; it exposes tools rather
  than resources. When `mcp__nixos__nix` is available, use it as directed and
  verify repository-specific claims against evaluation or pinned source.

## Validation

- Match checks to the change; see `README.md` for commands. In Codex use
  `./test.sh --sandbox` with `--lint`, selected `--home NAME`/`--dev SYSTEM`,
  or `--full`. Docs need whitespace/reference checks; shell edits need syntax,
  ShellCheck and relevant fixtures. Do not stage files just to validate.
- Iterate on specific settings, then evaluate affected activation derivations.
  Shared home edits must cover affected standalone and NixOS consumers; lock or
  shared flake changes need `--full`. Use the `nix-development` skill for
  consumer tracing and generated-config checks, not the audit skill.
- Use `./scripts/nix-sandbox` for additional Nix evaluation (`--offline` when
  cached, `path:.` for new files). It requires the daemon by default; the separate
  store requires explicit `NIX_SANDBOX_BACKEND=local`. Do not automatically retry
  failed commands in another store. See README for the Codex permission profile.
- Missing validation tools may be fetched from the binary cache; request network
  permission if blocked. Use runnable PATH tools if necessary and report that
  fallback. Complete independent checks if mount/tool execution fails; report
  exact failures and hand off only blocked checks via `./test.sh --path`.
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

## Secrets and storage

- Read `secrets/README.md` for secret work. Keep values sops-encrypted under
  `secrets/` and private age identities outside the repo. Never expose plaintext
  in Git, logs, chat, or the Nix store. Decrypting, editing, or rekeying secrets
  requires an explicit request; encrypted files/recipient metadata are safe to
  inspect. Use `sops.placeholder` and root-only `sops.templates` for system
  service files containing secrets.
- Before storage changes, read `README.md`, `hosts/pang14/disko.nix`, and
  `scripts/install-preflight`. Never automatically format, repartition, or roll
  back ZFS. Destructive operations require an explicit request and immediate
  device verification. The only allowed installation target is
  `/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B97472`;
  never modify the WD Blue SN580 containing Windows and Ubuntu.

Keep operator procedures in `README.md`, secrets procedures in
`secrets/README.md`, and agent constraints here. Avoid duplicating those docs;
add nested instructions only for different local commands or safety rules.
