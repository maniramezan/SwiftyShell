<!--
Thanks for contributing to SwiftyShell.

Keep PRs focused. If this PR adds a new typed command family, please complete
the checklist below. CI runs `Scripts/validate-traits.swift` and a per-trait
build matrix that will fail if any item is missing.
-->

## Summary

<!-- 1-3 sentences describing what this PR does and why. -->

## Changes

<!-- Bullet points listing the notable changes. -->

-

## Testing

<!-- How did you verify this change? -->

- [ ] `swift test --enable-all-traits` (full surface)
- [ ] `swift test` (default = Core only)

## New Command Family Checklist

If this PR adds a new typed command family, confirm each item:

- [ ] Trait declared in `Package.swift` (PascalCase, matches type name)
- [ ] Trait added to the `All` umbrella's `enabledTraits`
      (and to `CommonUtilities` if it lives under `Sources/SwiftyShell/Common/`)
- [ ] Every source file in the family is wrapped in `#if <Trait> ... #endif`
- [ ] Tests exist under `Tests/SwiftyShellTests/<Trait>/` (or `Common/` for utilities) and are wrapped in `#if <Trait>`
- [ ] `swift build --traits <Trait>` succeeds in isolation (no cross-family coupling)
- [ ] `swift test --enable-all-traits` passes
- [ ] Public API is documented per the rules in `AGENTS.md`
- [ ] DocC landing page (`SwiftyShell.docc/SwiftyShell.md`) and the trait table in `Articles/SelectingCommandFamilies.md` updated
- [ ] `swift Scripts/validate-traits.swift` passes locally
- [ ] `swift-format lint --strict` clean on every touched file

## Notes

<!-- Anything reviewers should know: tradeoffs, deferred work, related issues. -->
