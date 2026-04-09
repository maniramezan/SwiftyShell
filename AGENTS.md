# SwiftyShell — Agent Guide

This file is maintainer-oriented automation guidance for AI assistants working in this repository. It is public so contributors can audit and improve it, but it is optional and not required to build, test, or contribute to SwiftyShell.

SwiftyShell is a Swift package that provides type-safe shell command execution. It models shell concepts — commands, arguments, pipelines, redirection, workflows — as Swift values rather than raw strings.

## Repository Layout

### `Sources/SwiftyShell/Core/`

The execution primitives: `Command`, `Pipeline`, `ShellContext`, `ShellPlatform`, `Workflow`, `ShellError`, `ShellOutput`, `OutputDestination`, `CommandExecutor`, `MockExecutor`, `ToolConfiguration`, and the `ToolConfigurableCommandFamily` / `OutputRedirectingCommandFamily` / `RunnableCommandFamily` protocol hierarchy.

### `Sources/SwiftyShell/Git/`

Typed git client: `Git`, `GitStatus`, `GitStatusWorkflow`, `GitPullResult`, `GitFetchResult`, `GitWorkingTreeState`, and the internal `GitParsers` porcelain v2 parser.

### `Sources/SwiftyShell/Grep/`

Typed `grep` wrapper: `Grep` and `GrepPattern`.

### `Sources/SwiftyShell/Common/`

Typed wrappers for frequently used shell utilities: `Ls`, `Cp`, `Mkdir`, `Rm`, `Mv`, `Pwd`, `Jq`, and `JqArgument`. Each follows the same fluent builder conventions as all other command families.

### `Sources/SwiftyShell/Internal/Execution/`

`SubprocessExecutor` — the real process execution engine. `public` because it is the default for `ShellContext.init`. The `Internal/` folder is organizational only.

### `Sources/SwiftyShell/SwiftyShell.docc/`

DocC documentation catalog. `SwiftyShell.md` is the top-level landing page. Articles live under `Articles/`:

- `GettingStarted.md` — installation, first command, pipelines, testing
- `BuildingCommandFamilies.md` — how to author a new typed command family

### `Tests/SwiftyShellTests/`

Test suite. Sub-folders mirror the source layout: `Core/`, `Git/`, `Grep/`, `Pipelines/`.

### `Example/`

A standalone SwiftPM executable package that demonstrates real SwiftyShell usage. Depends on SwiftyShell via a local path reference.

### `.claude/skills/`

`swiftyshell.md` — the shared SwiftyShell agent skill for Claude and Codex/GPT-style assistants. Claude loads it directly from `.claude/skills/swiftyshell.md`; Codex/GPT agents should read that same file when a task involves generating SwiftyShell code, changing public API, or authoring command families. **Keep `AGENTS.md` and `.claude/skills/swiftyshell.md` aligned and update both files in the same PR whenever shared agent guidance or public API expectations change.**

### `.codex/skills/`

`swiftyshell.md` — a thin pointer for Codex/GPT-style assistants that redirects to `.claude/skills/swiftyshell.md`. Do not fork the skill content here; keep `.claude/skills/swiftyshell.md` as the canonical shared skill file.

## Build and Test Commands

```bash
# Build
swift build

# Run all tests
swift test

# Build for release
swift build -c release

# Run a single test file by class name
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

Use `MockExecutor` for unit tests. It implements `CommandExecutor`, mirrors real `run()` failure semantics for non-zero exits, validates timeout/output-limit configuration, and returns caller-supplied responses without spawning processes. Integration tests that require real executables should be clearly annotated.

### Agent Skill

`.claude/skills/swiftyshell.md` is the canonical shared skill for all agents working in this repo, including Claude and Codex/GPT assistants. `.codex/skills/swiftyshell.md` is only a pointer to that canonical file. When a task involves generating SwiftyShell code, changing public API, or adding command families, read the shared skill in addition to this guide. Keep `AGENTS.md` and `.claude/skills/swiftyshell.md` aligned and update both in the same PR whenever shared guidance or public API expectations change. The skill must reflect the implemented API, not the spec.

## Architecture Reference

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the design rationale, execution model, type-safety philosophy, and deferred roadmap.
