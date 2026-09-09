---
name: nix-development
description: Choose focused validation for implementation changes to this repository's Home Manager modules, Nix development outputs, or validation helpers. Use for development feedback loops, not configuration audits or deployment.
---

# Nix development

Follow [AGENTS.md](../../../AGENTS.md) for the default-shell environment and
safety constraints. Use [README's lightweight checks](../../../README.md#1-inspect-and-run-lightweight-checks)
for commands and scope mechanics. This skill selects behavior and consumer contexts.

- Trace imports from the changed module to standalone and NixOS-integrated Home
  Manager consumers. Select one consumer per distinct architecture, conditional,
  package set, module argument, or integration path; do not require every
  consumer when they evaluate the same option path with equivalent inputs. Do
  not infer consumers from filenames alone.
- Before editing, select affected contexts and checks, assign one validation
  owner, and establish a baseline when relevant. Iterate with narrow checks; batch
  repository-wide lint and selected activation evaluations at completion.
  Rerun a successful check only after its relevant inputs change.
- During iteration, evaluate the specific non-secret `config` attribute being
  changed. At completion, evaluate an activation derivation for each selected
  context. A setting evaluation alone is not that check. An option-only Home
  Manager change does not require full flake evaluation solely because one
  selected context is integrated into NixOS; evaluate that integrated home
  activation derivation narrowly. Reserve full evaluation for composition,
  shared package-set/argument wiring, lock changes, or uncertain boundaries.
- Inspect generated text at its owning option (for example,
  `config.home.file`, `config.xdg.configFile`, or `config.systemd.user.services`).
  Read pinned module source to locate it. A source path may be unrealized:
  inspect the generating expression or build only that small artifact if needed,
  never the entire home environment to obtain one file.
- For generated shell/editor configuration, run a focused syntax or headless
  fixture using temporary home/config directories and explicit dependencies.
  Avoid login shells, real user services, credentials, and activation scripts.
- Development-shell evaluation checks derivation generation, not whether every
  package builds or the shell works. Confirm the target architecture has an
  exposed output. Use tools already on `PATH`; enter the default shell explicitly
  only when testing shell behavior itself, not to obtain a linter.
- For runner changes, run its fixture tests to check scope isolation, argument
  handling and failure propagation, then exercise actual selected outputs.
  Report the scope checked and any untested consumers or runtime behavior.
