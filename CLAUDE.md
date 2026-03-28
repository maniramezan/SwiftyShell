# SwiftyShell — Agent Guide

SwiftyShell is a Swift package that provides type-safe shell command execution. It models shell concepts — commands, arguments, pipelines, redirection, workflows — as Swift values rather than raw strings.

## Repository Layout

```
Sources/SwiftyShell/
  Core/            # Command, Pipeline, ShellContext, Workflow, ShellError, MockExecutor
  Git/             # Git client, GitStatus, GitStatusWorkflow, git porcelain parsers
  Grep/            # Grep typed wrapper
  XcodeBuild/      # XcodeBuild builder and options (100+ option types)
  Xcrun/           # Xcrun wrapper and Simctl subcommands
  Internal/
    Execution/     # SubprocessExecutor — the process execution engine
Tests/SwiftyShellTests/
  Core/            # Command, workflow, and error tests
  Git/             # Git status and parser tests
  Grep/            # Grep tests
  Pipelines/       # Pipeline tests
  XcodeBuild/      # XcodeBuild builder tests
  Xcrun/           # Xcrun/Simctl tests
.claude/
  skills/
    swiftyshell.md # AI agent skill — keep in sync with public API
Spec.md            # Vision, API specification, acceptance criteria
```

## Build and Test Commands

```bash
# Build
swift build

# Run all tests
swift test

# Build for release
swift build -c release

# Run a single test target
swift test --filter SwiftyShellTests

# Run a specific test
swift test --filter CommandTests
```

## Key Conventions

### Public API Design

- All public types are value types (`struct`) conforming to `Sendable`
- Fluent builder pattern: every mutating method returns a new `Self` copy
- `init(context: ShellContext = .init())` is the standard entry point for typed clients
- Every typed client exposes `executable(_:)`, `env(_:_:)`, `workingDirectory(_:)`, `timeout(_:)`, `outputLimit(_:)`, `command() -> Command`, and `run() async throws`
- `ShellContext` is infrastructure, not a command namespace — `Command("pwd")` not `context.pwd()`

### Documentation — MANDATORY

**Every public declaration must have a `///` doc comment. No exceptions.**

This applies to:
- `public struct`, `public class`, `public enum`, `public protocol`
- `public var`, `public let` (properties)
- `public func`, `public init`
- `public typealias`
- `public case` on enums

**Rules:**
1. Type-level docs explain what the type _is_ and when to use it
2. Method-level docs explain what the method _does_ and note any non-obvious behaviour
3. Parameter docs (`- Parameter name:`) for non-trivial parameters
4. Use ``SymbolName`` double-backtick links to cross-reference related types
5. Include a code example in the type-level doc for all types that are primary API surface

**When you add or modify any public declaration, write or update its doc comment in the same change. Do not leave undocumented public API.**

Verify your work: after editing, scan the file for `public ` lines without a preceding `///` line.

### Error Handling

All failures surface as `ShellError`. Never throw raw `Error` or `NSError` from public code. Use `ShellError.spawnError` for unexpected process launch failures.

### Execution Engine

`SubprocessExecutor` (in `Internal/Execution/`) is `public` because `ShellContext.init` defaults to it. The `Internal/` folder label is organizational — it does not imply the type is hidden from callers.

Key invariant: `ProcessExitWaiter` must be created **before** calling `process.run()` to avoid the race where the process exits before `terminationHandler` is set.

### Workflows

`Workflow<Value>` is single-use — `run()` consumes it. Typed workflow types (`GitStatusWorkflow`) queue steps until `run()` is awaited. Never call `run()` more than once on the same workflow instance.

### Testing

Use `MockExecutor` for unit tests. It implements `CommandExecutor` and returns caller-supplied responses without spawning processes. Integration tests that require real executables should be clearly annotated.

### Agent Skill

`.claude/skills/swiftyshell.md` teaches AI agents how to generate correct SwiftyShell code. Update it in the same PR as any public API change. The skill must reflect the implemented API, not the spec.

## Spec vs. Implementation

`Spec.md` describes the intended design. When in doubt, the implemented code is authoritative; the spec describes the direction.

Notable gaps as of initial open-source release:
- Linux support is described in the spec but not yet validated in CI
- No DocC documentation target is configured yet
