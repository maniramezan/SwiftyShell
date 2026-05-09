# Contributing to SwiftyShell

Thank you for your interest in contributing. This document covers setup, conventions, and the review process.

## Getting Started

### Prerequisites

- macOS 15.0+
- Docker Desktop on macOS, or Docker Engine on Linux, if you want to run the Linux validation helpers locally
- Linux is supported in CI with Swift 6.1.3 on Ubuntu (`swift:6.1.3-noble`); use either macOS or Linux locally
- Swift 6.1+ (`swift --version`)

### Clone and Build

```bash
git clone https://github.com/maniramezan/SwiftyShell
cd SwiftyShell
swift build -c release -Xswiftc -warnings-as-errors
```

### Run Tests

```bash
swift test -Xswiftc -warnings-as-errors
```

Tests use the Swift Testing framework (`@Test` macro). All tests must pass before a PR is reviewed.

The GitHub Actions matrix runs both macOS and Linux jobs. If you are changing execution or process-handling code, wait for both jobs before calling the change ready.

### Run Linux Locally With Docker

The repository includes Docker-based helpers that mirror the Linux CI build and test commands:

```bash
make check
make help
make linux-build
make linux-test
make linux-ci

Scripts/linux-build.sh
Scripts/linux-test.sh
Scripts/linux-ci.sh
```

Use `Scripts/linux-shell.sh` to open an interactive shell in the pinned Swift Linux image.

The `Makefile` is a thin wrapper around those scripts, so `make linux-test` and `Scripts/linux-test.sh` are equivalent. Linux Docker builds use `.build/linux-docker` as their SwiftPM scratch path so they do not collide with the host platform's `.build` state.

For the standard local pre-PR pass, run `make check`. It bundles:

- `swift-format lint --strict --recursive Sources Tests Scripts`
- `swift test -Xswiftc -warnings-as-errors`
- `swift -warnings-as-errors Scripts/validate-traits.swift`
- `swift -warnings-as-errors Scripts/validate-docc-coverage.swift`
- `swift package -Xswiftc -warnings-as-errors --allow-writing-to-directory docs generate-documentation --target SwiftyShell --output-path docs --transform-for-static-hosting --hosting-base-path SwiftyShell`
- `swift test --enable-all-traits --enable-code-coverage -Xswiftc -warnings-as-errors`
- `swift -warnings-as-errors Scripts/validate-code-coverage.swift --input <codecov-path> --minimum-line-coverage 84`
- `Scripts/linux-ci.sh`

On Apple Silicon Macs, the helpers run a native Linux ARM container by default for speed. To match GitHub Actions' `amd64` container more closely, set `SWIFTYSHELL_LINUX_PLATFORM=linux/amd64`:

```bash
SWIFTYSHELL_LINUX_PLATFORM=linux/amd64 Scripts/linux-ci.sh --traits All
make linux-ci-amd64
```

For macOS validation when working from Linux, rely on GitHub Actions' macOS runners.

### Definition of Done

Every change — human- or agent-authored, including docs-only edits that touch Swift snippets — must satisfy these gates before it is considered done:

1. **Tests pass** — `swift test -Xswiftc -warnings-as-errors` is green.
2. **Format is clean** — `swift-format lint --strict --recursive <paths-you-touched>` reports no errors, and any newly written Swift passes `swift-format format -i <file>` without a subsequent lint complaint.
3. **DocC builds when needed** — if you changed public API or DocC content, run `swift package -Xswiftc -warnings-as-errors --allow-writing-to-directory docs generate-documentation --target SwiftyShell --output-path docs --transform-for-static-hosting --hosting-base-path SwiftyShell`.

Do not open a PR, mark work complete, or ask for review until the relevant commands succeed on the files you changed. If the format rules feel wrong for a specific construct, change `.swift-format` in the same PR and explain why — don't bypass the gate.

The tree is currently fully compliant with `.swift-format`; `swift-format lint --strict --recursive Sources Tests` exits clean. Keep it that way.

## Code Style

### Swift

- Follow Swift API Design Guidelines
- **All `public` types, properties, methods, inits, typealiases, and enum cases must have `///` doc comments — no exceptions**
  - Type docs: explain what it is and include a code example for primary API types
  - Method docs: explain what it does; list thrown `ShellError` cases with `- Throws:`
  - Use ``SymbolName`` double-backtick syntax to cross-reference related types
  - After editing a file, verify every `public ` line has a `///` comment above it
- No force unwraps (`!`) — use `guard`, `if let`, or `throws`
- Prefer `async`/`await` over callbacks
- Prefer value types (`struct`) over reference types (`class`) for public API
- All public types must conform to `Sendable`
- Use `Result` or `throws` for explicit error handling

### Adding a New Typed Command Family

A typed client (like `Git` or `Grep`) is worth adding when it provides meaningful value over raw `Command` usage — typed results, conditional follow-up steps, or a large discoverable option surface.

New clients must:

1. Follow the same fluent builder conventions as existing clients
2. Accept `context: ShellContext` in `init`
3. Expose `executable(_:)`, `env(_:_:)`, `workingDirectory(_:)`, `timeout(_:)`, `outputLimit(_:)` overrides
4. Expose `command() -> Command` and `run() async throws -> ShellOutput`
5. Have corresponding tests
6. **Be wired behind a SwiftPM trait** (see [Package Traits](#package-traits) below)
7. Update `.claude/skills/swiftyshell.md` in the same PR (see below)

## Package Traits

SwiftyShell uses [SwiftPM Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) so each typed command family is opt-in. The default trait set is **empty** — only `Core/` and `Internal/` types compile by default. Consumers select families via `traits:` on `.package(...)`. See the [Selecting Command Families](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/selectingcommandfamilies) DocC article for the consumer-facing reference.

### When You Add a New Family

1. Add the directory or file under `Sources/SwiftyShell/<Family>/` (or `Sources/SwiftyShell/Common/<Family>.swift`).
2. Wrap every source file in `#if <Family> ... #endif`.
3. Add `.trait(name: "<Family>", description: "...")` to the `traits:` array in `Package.swift`.
4. Add `<Family>` to the `All` umbrella's `enabledTraits`. If the family lives under `Common/`, also add it to `CommonUtilities`.
5. Add tests under `Tests/SwiftyShellTests/<Family>/` (or `Tests/SwiftyShellTests/Common/<Family>Tests.swift`) and wrap them in `#if <Family>`. Cross-family tests use combined guards like `#if Git && Grep`.
6. Run `swift -warnings-as-errors Scripts/validate-traits.swift` — it must exit clean.
7. Verify the trait builds and tests in isolation:

   ```bash
   swift build --traits <Family> -Xswiftc -warnings-as-errors
   swift test  --traits <Family> -Xswiftc -warnings-as-errors
   swift build --enable-all-traits -Xswiftc -warnings-as-errors
   swift test  --enable-all-traits -Xswiftc -warnings-as-errors
   ```

`Core/` and `Internal/` files are **never** gated. CI runs `validate-traits` first and then a build/test matrix across `""`, each per-family trait, `CommonUtilities`, and `All` on macOS 15 and Linux. A new family that bypasses the wiring will fail validation before any build job runs. The pull-request template (`.github/PULL_REQUEST_TEMPLATE.md`) has a checklist that mirrors these steps.

## Testing

### Unit Tests

Use `MockExecutor` to write unit tests that don't spawn real processes:

```swift
@Test func statusReturnsBranch() async throws {
    let context = ShellContext(executor: MockExecutor(stdout: "## main...origin/main\n"))
    let status = try await Git(context: context).status().run()
    #expect(status.branch == "main")
}
```

### Integration Tests

Integration tests that invoke real executables should be tagged or isolated so they can be skipped in environments without the relevant tools installed.

### Coverage Requirements

All error paths in new code must be tested:
- Non-zero exit
- Timeout
- Cancellation (where applicable)
- Workflow condition failure (for new workflow types)

## Pull Requests

Before opening a PR, open a GitHub issue to describe the change and get agreement on the approach.

1. Branch from `main` and open a PR when ready
2. Keep PRs focused — one logical change per PR
3. Include tests for all new behavior
4. Update doc comments for changed public API
5. Run `swift test -Xswiftc -warnings-as-errors` and confirm all tests pass
6. Run `swift-format lint --strict` on the files you touched (and `swift-format format -i` to auto-fix) — no lint errors in changed files
7. If you changed public API or DocC content, run the DocC generation command from the Definition of Done and update DocC where needed
8. If you added or modified a command family, run `swift -warnings-as-errors Scripts/validate-traits.swift` and confirm it exits clean
9. Describe _why_ in the PR body, not just _what_

## Maintainer Automation Notes

The agent-instruction files (`AGENTS.md`, `CLAUDE.md`, `.claude/skills/swiftyshell.md`, and `.codex/skills/swiftyshell.md`) are maintainer-oriented automation notes. They are intentionally public so other maintainers and contributors can improve them, but they are optional and not required to build, test, or contribute to SwiftyShell.

Update these files only when you are changing shared agent guidance or the public API they describe.

### Updating the Agent Skill

`.claude/skills/swiftyshell.md` is the canonical shared skill for repository automation. It must stay in sync with the implemented public API.

**Update the skill file in the same PR whenever you:**

- Add a new typed client or method
- Change an existing method's signature
- Add or rename `ShellError` cases
- Change execution semantics (pipeline exit behavior, environment merging, etc.)

The skill is derived from the implementation, not the spec. It must reflect what is actually shipped.

## Reporting Issues

Open a GitHub issue with:
- Swift version and operating system version/distribution
- A minimal reproduction case
- The expected versus actual behavior

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
