---
name: nix-development
description: Choose focused validation for implementation changes to this repository's Home Manager modules, Nix development outputs, or validation helpers. Use for development feedback loops, not configuration audits or deployment.
---

# Nix development

Use the scope commands in the repository README's lightweight-check section.
Keep command mechanics in the runner; this skill covers what to validate.

- Trace imports from the changed module to `homes/` and NixOS consumers.
  A syntax-only module can use one selected home; a common CLI module may affect
  gateway, OCI, syntax, and pang14. Architecture-specific branches need a consumer
  of each affected architecture. Do not infer consumers from filenames alone.
- During iteration, evaluate the specific non-secret `config` attribute being
  changed. At completion, evaluate affected activation derivations to force
  broader module validation. A setting evaluation alone is not that check.
- Inspect generated text at its owning option (for example,
  `config.home.file`, `config.xdg.configFile`, or `config.systemd.user.services`).
  Read pinned module source to locate it. A source path may be unrealized:
  inspect the generating expression or build only that small artifact if needed,
  never the entire home environment to obtain one file.
- For generated shell/editor configuration, run a focused syntax or headless
  fixture using temporary home/config directories and explicit dependencies.
  Avoid login shells, real user services, credentials, and activation scripts.
- Development-shell evaluation checks derivation generation, not whether every
  package builds or the shell works. Use a small selected artifact or fixture
  when behavior needs testing; do not enter the broad shell just to obtain a
  linter. Confirm the target architecture has an exposed output.
- For runner changes, run its fixture tests to check scope isolation, argument
  handling and failure propagation, then exercise actual selected outputs.
  Report the scope checked and any untested consumers or runtime behavior.
