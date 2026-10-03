---
name: nix-development
description: Select focused validation for this repository's NixOS and Home Manager modules, development outputs, scripts, and validation helpers. Use for implementation feedback loops, not configuration audits or deployment.
---

# Nix development

Follow [AGENTS.md](../../../AGENTS.md) for constraints and
[README's lightweight checks](../../../README.md#1-inspect-and-run-lightweight-checks)
for commands, scope mechanics, generated-file inspection, and troubleshooting.

## Select the loop

| Change | Iterate with | Complete with |
| --- | --- | --- |
| Documentation or skill guidance | Referenced paths/commands | Worktree and staged whitespace checks; validate skill metadata when changed |
| Runner or apply helper | Relevant fake-tool fixtures | Source checks and selected fixtures in one runner invocation |
| Windows scripts | PowerShell parser and mocked orchestration fixtures | Source checks and Windows fixtures; identify behavior requiring Windows |
| Home Manager options | Changed non-secret option or generated configuration | Source checks and selected home activation derivations |
| NixOS options | Changed non-secret system option or generated configuration | Source checks and selected system assertions; identify live/root-only behavior |
| Development shell | Selected shell derivations; exercise shell behavior only when changed | Source checks and affected architectures |
| Imports, shared package sets/arguments, flake composition, or lock | Focused affected outputs | Full evaluation and relevant fixtures; small native check builds for changed check wiring |

Trace imports before selecting consumers. Cover distinct architectures,
conditionals, package sets, module arguments, or integration paths relevant to
the change; equivalent consumers need not all run. NixOS assertions do not
force every service option or prove runtime behavior: also inspect the changed
option and its generated configuration where relevant. Home option evaluation
does not replace the selected activation derivation check. An integrated home
option change alone does not require full flake evaluation. Use full evaluation
when the affected boundary remains uncertain.

Select checks before editing. Establish a baseline when investigating a failure
or when existing behavior is uncertain, rather than routinely repeating every
completion check before the change. Use one validation owner when agents are
collaborating. Batch completion scopes and rerun successful checks only when
relevant inputs change. Fixtures remain independent of optional inspections and
output failures; a failed inspection must not prevent completion checks.

## Inspect behavior

- Locate generated configuration in pinned module source and inspect its owning
  option (`home.file`, `xdg.configFile`, `environment.etc`, or service definitions).
  Discover evaluated attribute keys before selecting files; home targets may be
  absolute. Follow README's pure, quoted installable procedure to realize only
  the selected source when text is not already available. Avoid building whole
  home/system environments to obtain one file.
- For changed generated shell/editor behavior, use focused syntax or headless
  fixtures with temporary home/config directories and explicit dependencies.
  Avoid login shells, credentials, real services, and activation scripts.
- Runner fixtures test argument handling, scope isolation, and failure propagation
  with fake tools. Also exercise actual selected outputs after changing evaluation
  wiring. Apply fixtures must mock hostname and kernel detection so they work on
  both native Linux and WSL.
- Windows fixtures parse all scripts and mock verification/update orchestration.
  They do not prove DSC resource behavior, provisioning, or WSL installation.
- Development-shell derivation evaluation does not prove every package builds or
  the shell works. Use existing PATH tools; enter a shell only to test its behavior.

Report checks performed, untested consumers, and runtime limitations as required
by AGENTS.md.
