---
name: nix-config-review
description: Review a Nix, NixOS, Home Manager, or flake repository for idiomatic Nix, native-option replacements, unnecessary abstractions, configuration complexity, and closure-size drivers. Use when the user asks for a Nix configuration audit, simplification review, best-practice assessment, or closure analysis; do not use for routine implementation that does not request a review.
---

# Nix Configuration Review

Produce an evidence-backed review, not a generic Nix style checklist. Read the repository's `AGENTS.md` and operator documentation first, inspect the worktree without changing it, and respect all local validation, deployment, storage, and secrets constraints.

## Establish the review boundary

Infer the requested scope from the prompt. If none is stated, review the flake structure, host composition, reusable NixOS modules, Home Manager modules, overlays/package sets, custom options, generated files or scripts, and package-selection patterns. Do not edit configuration unless the user separately requests fixes.

Inspect `git status --short` and relevant imports before drawing conclusions. Treat uncommitted changes as user work. Never decrypt secrets, activate a configuration, build a full system closure, or mutate live services as part of a review.

## Gather version-matched evidence

Use evidence in this order:

1. Narrow evaluation of the repository's locked outputs and option declarations.
2. Source and tests from the revisions pinned by `flake.lock`.
3. A Nix or NixOS MCP server, when exposed, for option/package lookup, version-specific documentation, or package metadata.
4. Current authoritative online documentation from NixOS, Nix, Home Manager, and the upstream projects represented by locked inputs.

Search local pinned sources with `rg` before browsing. Browse authoritative online documentation during every substantive review so recommendations are checked against maintained guidance, but do not let current online docs override behavior in an older or different pinned revision. State the relevant pinned branch/revision when it affects a finding.

Discover whether a Nix-specific MCP is available; use it when it can answer the question more directly. Verify MCP claims against the locked source or evaluation when practical. If it is unavailable, proceed with local evaluation and authoritative web sources and mention the unavailable evidence channel briefly; do not treat absence as a blocker.

For unfamiliar options, inspect evaluated option metadata or their pinned declarations. Do not recommend an option solely because it appears in a blog, forum, wiki, search snippet, or a different release.

Read [references/review-rubric.md](references/review-rubric.md) before analyzing findings or closure impact.

## Analyze deliberately

Trace imports and configuration flow before criticizing duplication or indirection. Account for the repository's intended reuse boundaries, platform boundaries, state-version policy, secrets ownership, and deployment model.

Prefer findings that identify a concrete improvement:

- replace hand-written files, shell fragments, services, or custom options with a supported NixOS/Home Manager option;
- use module-system composition, `lib` helpers, package options, or existing input APIs more directly;
- remove pass-through values, wrappers, repeated imports, redundant defaults, unnecessary package-set instantiations, or abstractions without a credible reuse or policy purpose;
- move host identity and hardware policy to the proper boundary without over-generalizing one host;
- identify duplicate packages, broad meta-packages, propagated runtimes, debug/docs outputs, multiple package-set revisions, or optional features that materially affect closures.

Do not label code non-idiomatic merely because another spelling is shorter. Preserve useful capability modules and explicit composition when they communicate policy or enable credible reuse. Treat readability, evaluation behavior, operational safety, and closure impact as separate concerns.

Use narrow read-only evaluation where it materially tests a claim. Use closure inspection commands only if a suitable realized derivation already exists or the user authorizes an appropriately scoped build. Never infer byte savings from source syntax. Separate evaluation simplification from realized closure reduction.

## Deliver the review

Lead with the highest-value findings, ordered by likely impact and confidence. For each finding include:

- location and current behavior;
- why it matters;
- a concrete native or simpler alternative;
- evidence, including version-matched option/source references and authoritative links;
- tradeoffs or reasons the current design may be intentional;
- confidence and, for closure findings, measured size/difference or a precise command to measure it.

Group lower-confidence ideas as opportunities to investigate, not defects. Include a short section for sound existing choices so the review does not incentivize churn. End with checks performed, evidence limitations, and confirmation that no full build or activation ran.
