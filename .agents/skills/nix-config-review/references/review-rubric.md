# Review rubric

Use this rubric to turn observations into actionable, appropriately qualified findings.

## Idiomatic module usage

- Prefer declared NixOS or Home Manager options over generated configuration and activation scripts when the native option expresses the same semantics.
- Check option declarations, types, defaults, examples, assertions, and generated definitions in the locked source before proposing a replacement.
- Look for unconditional policy that belongs behind `lib.mkIf`, values incorrectly forced with `mkForce`, and priority manipulation that masks module ownership problems.
- Distinguish deliberate explicit composition from boilerplate. An import list or small capability module is not waste merely because it has one current consumer.
- Flag custom options only when they duplicate a stable native option, merely transport values already available at the correct boundary, or create more indirection than policy. Preserve options that define a useful repository interface.

## Simplification and complexity

Trace each abstraction through its callers. Look for:

- functions that only rename arguments or reconstruct existing attribute sets;
- repeated `nixpkgs` imports that could use an existing package set without changing configuration or platform semantics;
- duplicated package lists, overlays, module arguments, or host metadata;
- generated shell/config text replaceable by structured options;
- platform leakage such as shared Home Manager modules depending on NixOS-only state;
- conditional trees that module composition, defaults, `optionalAttrs`, `optionals`, `mkMerge`, or typed submodules can express more clearly;
- aliases or compatibility layers with no remaining caller.

Recommend deletion only after verifying all imports and references. Optimize for a clearer ownership model, not the lowest line count.

## Closure impact

Classify closure observations as one of:

1. **Measured:** compare realized closures using `nix path-info -Sh`, `nix path-info -rs`, `nix store diff-closures`, or equivalent version-supported commands.
2. **Cache-backed estimate:** exact output paths and their references have binary-cache size metadata; name the cache and distinguish this from local disk usage. Missing custom outputs prevent a complete estimate.
3. **Structurally confirmed:** the evaluated configuration demonstrably adds a package/output/runtime, but its byte impact was not measured.
4. **Suspected:** package metadata or dependency structure suggests impact; provide a measurement command rather than a size claim.

Inspect common drivers:

- desktop environments, browsers, IDEs, language servers, compilers, SDKs, TeX, fonts, firmware, containers, and virtualization stacks;
- optional package features and services that pull large runtime trees;
- both stable and unstable variants of the same dependency graph;
- duplicate application delivery through system packages and Home Manager;
- packages included solely to support generated scripts when a native module already supplies the executable;
- documentation, development, debug, source, or static outputs included unintentionally;
- `environment.systemPackages`, `home.packages`, service package defaults, and Nixvim/plugin dependencies.

Do not assume that fewer Nix expressions, fewer modules, disabled services, `let` bindings, or syntax refactors shrink the closure. Package references and selected outputs determine realized size. Note that store-path sharing can make per-package sizes non-additive.

## Severity and confidence

Rank findings using practical impact:

- **High:** correctness, maintainability, or measured closure improvement with a clear supported replacement.
- **Medium:** meaningful simplification or structurally confirmed dependency reduction with manageable tradeoffs.
- **Low:** localized cleanup, consistency improvement, or an unmeasured opportunity.

Use high confidence only when evaluation, pinned source, or measurement directly supports the claim. Use medium confidence for authoritative version-matched documentation plus clear code tracing. Mark hypotheses low confidence and say what would confirm them.

Avoid style-only findings already covered by nixfmt, Statix, or Deadnix unless they expose a design issue those tools cannot explain.
