---
name: nix-config-review
description: Review a Nix, NixOS, Home Manager, or flake repository for idiomatic Nix, native-option replacements, unnecessary abstractions, configuration complexity, and closure-size drivers. Use when the user asks for a Nix configuration audit, simplification review, best-practice assessment, or closure analysis; do not use for routine implementation that does not request a review.
---

# Nix configuration review

Review the requested configuration scope; implement fixes only when requested.
Follow [AGENTS.md](../../../AGENTS.md) for environment, validation, deployment,
and secrets constraints. Tools come from the default development shell.

Read [references/review-rubric.md](references/review-rubric.md) for module,
complexity, and closure criteria. For closure commands and tool selection, use
[README.md](../../../README.md#review-tools-and-closure-analysis).

## Evidence and scope

If the request gives no narrower boundary, inspect flake composition, host and
home modules, package sets, custom options, generated files, and package selection.
Trace imports and callers before recommending removal or moving policy.

Ground repository-specific findings in narrow evaluation or sources pinned by
`flake.lock`. Use the available Nix MCP tools as directed by AGENTS.md, and
verify results against those pinned inputs. Consult authoritative upstream
documentation when needed; identify version differences that affect a finding.

Distinguish native-option replacements and unnecessary indirection from
intentional capability modules, platform boundaries, and explicit composition.
A shorter expression alone is not an improvement.

For closure findings, use existing realized paths or exact binary-cache metadata
where available. Otherwise report structural evidence or an unmeasured hypothesis.
Follow the README's measurement limits; source simplification does not prove byte
savings.

## Report

Lead with findings ordered by impact and confidence. Include the location,
current behavior, proposed improvement, supporting evidence, and relevant
tradeoffs. Label uncertain opportunities clearly and preserve sound intentional
choices. End with checks performed and limitations, following AGENTS.md's handoff
requirements.
