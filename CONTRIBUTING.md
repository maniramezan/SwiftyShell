# Contributing to SwiftyShell

Thank you for your interest in contributing. This document covers setup, conventions, and the review process.

## Getting Started

### Prerequisites

- macOS 15.0+
- Swift 6.1+ (`swift --version`)
- Xcode 16+ (optional but useful for debugging)

### Clone and Build

```bash
git clone https://github.com/maniramezan/SwiftyShell
cd SwiftyShell
swift build
```

### Run Tests

```bash
swift test
```

Tests use the Swift Testing framework (`@Test` macro). All tests must pass before a PR is reviewed.

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

### Access Control

- Default to the most restrictive access level that meets the need
- Implementation details go in `Internal/` but may still be `public` if the spec requires it
- Mark types `@unchecked Sendable` only when thread-safety is verified and documented with a comment explaining why

### Adding a New Typed Command Family

A typed client (like `Git` or `Grep`) is worth adding when it provides meaningful value over raw `Command` usage — typed results, conditional follow-up steps, or a large discoverable option surface.

New clients must:

1. Follow the same fluent builder conventions as existing clients
2. Accept `context: ShellContext` in `init`
3. Expose `executable(_:)`, `env(_:_:)`, `workingDirectory(_:)`, `timeout(_:)`, `outputLimit(_:)` overrides
4. Expose `command() -> Command` and `run() async throws -> ShellOutput`
5. Have corresponding tests
6. Update `.claude/skills/swiftyshell.md` in the same PR (see below)

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

1. Branch from `main`: `git checkout -b feature/<name>`
2. Keep PRs focused — one logical change per PR
3. Include tests for all new behavior
4. Update doc comments for changed public API
5. Run `swift test` and confirm all tests pass
6. Describe _why_ in the PR body, not just _what_

### Commit Messages

Use the imperative mood in the subject line:

```
Add Simctl.recordVideo(_:) command
Fix terminationHandler race in SubprocessExecutor
```

Co-author attribution is welcome:
```
Co-Authored-By: Your Name <you@example.com>
```

## Updating the Agent Skill

`.claude/skills/swiftyshell.md` is the AI agent skill for this library. It must stay in sync with the implemented public API.

**Update the skill file in the same PR whenever you:**

- Add a new typed client or method
- Change an existing method's signature
- Add or rename `ShellError` cases
- Change execution semantics (pipeline exit behavior, environment merging, etc.)

The skill is derived from the implementation, not the spec. It must reflect what is actually shipped.

## Reporting Issues

Open a GitHub issue with:
- Swift and macOS versions
- A minimal reproduction case
- The expected versus actual behavior

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
