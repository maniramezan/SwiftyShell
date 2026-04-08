# SwiftyShell Architecture

Design rationale, execution model, type-safety philosophy, and deferred roadmap.

## Vision

SwiftyShell provides type-safe shell support in Swift. The goal is not merely to run subprocesses safely, but to model common shell concepts as Swift types:

- commands and arguments
- executable resolution
- environment and working directory
- pipelines
- redirection
- deferred workflows
- typed command families such as `Git` and `Grep`

The public API is a Swift-first shell DSL rather than a thin wrapper around raw shell strings.

---

## Execution Model

SwiftyShell has two complementary execution styles:

### 1. Core shell execution

Build a `Command` or `Pipeline`, override config as needed, then run it in a `ShellContext`:

```swift
let output = try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .timeout(120)
    .run(in: context)
```

### 2. Typed workflow execution

Start from a typed client, queue domain operations fluently, then await the terminal `run()`:

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()
```

This split keeps the core shell model general while allowing high-level typed workflows where they add real value.

---

## Type Safety

"Type-safe shell support" means:

1. **No raw shell strings as the main API** — users compose commands, pipelines, and workflows as Swift values rather than passing opaque strings to `sh`.

2. **Explicit executable and argument boundaries** — executable names, arguments, environment values, and output destinations are separate Swift values, never concatenated strings.

3. **Typed shell semantics** — pipelines, redirections, and workflow gates are represented directly in Swift rather than parsed from shell syntax.

4. **Typed command families where it matters** — domain APIs such as `Git` return typed values like `GitStatus` instead of unstructured strings.

5. **Concrete error handling** — failures are represented as named `ShellError` cases, not loosely structured strings or opaque `NSError` values.

This does **not** mean every executable on the system gets its own Swift type, or that raw shell script strings are parsed automatically.

---

## Execution Behavior

### Executable Resolution

- A `Command` starts with an executable identifier such as `"git"` or `"pwd"`.
- At runtime, the executor resolves that identifier against an explicit per-command `.executable(...)` override if present, otherwise against `ShellContext.searchPaths`.
- Per-command or per-client executable overrides always win over shell-wide defaults.

### Environment & Working Directory

- `ShellContext` provides default environment variables and working directory.
- `Command` and typed clients may override either independently.
- `env(_:_:)` and `env(_:)` set keys that override matching keys from the context environment; keys present only in the context pass through unchanged.
- Working directory defaults to the process cwd when neither the context nor the command sets one.

### Output Handling

- Output is buffered in memory by default (stdout and stderr decoded as UTF-8).
- Default maximum captured output size is 10 MiB; configurable via `ShellContext.defaultOutputLimit` or per-command/client `.outputLimit(_:)`.
- Exceeding the limit throws `ShellError.outputLimitExceeded`.
- Invalid UTF-8 throws `ShellError.decodingError`.
- Redirected output (`OutputDestination.file` or `.discard`) is not also captured.

### Exit Code Behavior

- `run()` throws `ShellError.exitFailure` for any non-zero exit.
- `ShellError.exitFailure` always carries the full `ShellOutput` for diagnostics.

### Pipelines

- Pipelines are explicit value types, not parsed shell strings.
- `pipe(to:)` connects stdout from one command to stdin of the next.
- If any stage exits non-zero, the pipeline throws `ShellError.exitFailure`; remaining stages are terminated.

### Timeout & Cancellation

- The most specific timeout wins (per-command > per-client > context default).
- On timeout: `SIGTERM` → short grace period → `SIGKILL` → `ShellError.timeout` with partial output.
- Swift task cancellation follows the same `SIGTERM` → `SIGKILL` sequence and throws `ShellError.cancelled`.
- stdin is always closed (`/dev/null`) for all spawned processes.

### Deferred Workflow Semantics

- Typed workflow steps queue operations until `run()` is awaited.
- `map` and `require` transformations do not trigger execution.
- Workflows are single-use — `run()` is a `consuming` call. Rebuild from the source client to repeat.
- Concurrent tasks must each build and run their own workflow instances.

---

## Command-Family Design

### Why `ToolConfigurableCommandFamily` Protocols

Fluent helper methods are shared through protocols instead of re-implemented per type:

| Protocol | Adds |
|---|---|
| `ToolConfigurableCommandFamily` | `executable`, `env`, `workingDirectory`, `timeout`, `outputLimit` |
| `OutputRedirectingCommandFamily` | `stdout`, `stderr` |
| `RunnableCommandFamily` | `command()`, `run()` |

New typed clients should conform to `RunnableCommandFamily` unless they have a specific reason to stop at a lower tier.

### When to Add a Typed Client

A typed client is worth adding when it provides meaningful value over raw `Command` usage:
- typed structured results (like `GitStatus`)
- conditional follow-up steps (like `GitStatusWorkflow.pull()`)
- a large, discoverable option surface

Simple invocations that just run a command and return `ShellOutput` rarely justify a typed client.

### Why ShellContext Is Not a Command Namespace

`ShellContext` is infrastructure, not a namespace. That means:
- `Command("pwd")` — not `context.pwd()`
- `Git(context: context)` — not `context.git`

This keeps the API aligned with how developers think about shell work: a configuration environment, command values, and typed workflows where useful.

---

## Testing Architecture

### Protocol-Based Seams

`CommandExecutor` is the injection point:

```swift
public protocol CommandExecutor: Sendable {
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput
    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
}
```

`ShellContext` stores the executor, so both raw commands and typed clients use the same injectable runtime. In tests, inject `MockExecutor`:

```swift
let context = ShellContext(executor: MockExecutor(stdout: "main\n"))
```

---

## Platforms

| Platform | Minimum version |
|---|---|
| macOS | 15.0 |
| Linux | Ubuntu 22.04 (glibc 2.35+) |
| Swift | 6.1+ |

Windows is out of scope for v1.

---

## Deferred Features (v2+)

- Explicit unsafe raw shell-string escape hatch
- Alternative pipeline failure modes as explicit opt-ins
- Interactive stdin
- Additional typed command families (e.g. `Docker`, `Homebrew`)
- Windows support
- Alternative packaging if command families grow substantially
