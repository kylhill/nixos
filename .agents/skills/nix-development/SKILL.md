---
name: nix-development
description: Choose focused validation for implementation changes to this repository's Home Manager modules, Nix development outputs, or validation helpers. Use for development feedback loops, not configuration audits or deployment.
---

# Nix development

Use the commands and scope mechanics in README's lightweight-check section. This
skill only decides which behavior and consumer contexts need validation.

- Trace imports from the changed module to standalone and NixOS-integrated Home
  Manager consumers. Select one consumer per distinct architecture, conditional,
  package set, module argument, or integration path; do not require every
  consumer when they evaluate the same option path with equivalent inputs. Do
  not infer consumers from filenames alone.
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
  package builds or the shell works. Use a small selected artifact or fixture
  when behavior needs testing; do not enter the broad shell just to obtain a
  linter. Confirm the target architecture has an exposed output.
- For runner changes, run its fixture tests to check scope isolation, argument
  handling and failure propagation, then exercise actual selected outputs.
  Report the scope checked and any untested consumers or runtime behavior.
