# SwiftyShell Architecture

Design rationale, execution model, type-safety philosophy, and deferred roadmap.

## Vision

SwiftyShell provides a Swift-typed model for shell execution. It models common shell concepts as Swift values:

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
let output = try await Command("ruby", arguments: "deploy.rb")
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

"Type-safe shell support" describes the API shape, not a security guarantee about an executable or its inputs:

1. **No raw shell strings as the main API** — users compose commands, pipelines, and workflows as Swift values rather than passing opaque strings to `sh`.

2. **Explicit executable and argument boundaries** — executable names, arguments, environment values, and output destinations are separate Swift values. `Command` passes each argument as one argv entry without shell parsing.

3. **Typed shell semantics** — pipelines, redirections, and workflow gates are represented directly in Swift rather than parsed from shell syntax.

4. **Typed command families where it matters** — domain APIs such as `Git` return typed values like `GitStatus` instead of unstructured strings.

5. **Concrete execution errors** — built-in executors represent their failures as named `ShellError` cases. Workflow transforms and custom executors can throw other `Error` values.

This does **not** validate arbitrary strings accepted by typed wrappers, make invoked tools trustworthy, or make shell scripts safe. Passing untrusted input to an interpreter (`sh -c`, `python -c`), tool-specific expression language, environment variable, executable override, or writable output path remains the caller's security boundary.

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
- Default output limit is unlimited (`0`); configurable via `ShellContext.defaultOutputLimit` or per-command/client `.outputLimit(_:)`. Pass a positive byte count to cap captured output.
- For one command, the limit is the combined captured stdout and stderr byte count. Exceeding it terminates the command and throws `ShellError.outputLimitExceeded` with at most the configured number of captured bytes.
- Invalid UTF-8 throws `ShellError.decodingError`.
- Negative timeout or output-limit values throw `ShellError.invalidConfiguration`.
- Redirected output (`OutputDestination.file` or `.discard`) is not also captured.

### Exit Code Behavior

- The built-in `SubprocessExecutor` and `MockExecutor` throw `ShellError.exitFailure` for a non-zero exit from `run()`; raw `Command` calls follow the same rule as typed families.
- `ShellError.exitFailure` carries captured output. Streams sent to `.file` or `.discard` are absent, and an output limit can terminate execution before a later exit failure.

### Pipelines

- Pipelines are explicit value types, not parsed shell strings.
- `pipe(to:)` connects stdout from one command to stdin of the next.
- All stages run concurrently. If a stage exits non-zero, the pipeline reports an observed failing stage and cancels the remaining stage tasks; concurrent failures do not provide a deterministic "first by pipeline order" guarantee.
- Successful output contains the final stage's captured stdout and captured stderr concatenated in stage order. An exit failure uses the failing stage's exit code with that aggregate captured output.
- Each stage has its own captured-output limit. Intermediate stdout is piped rather than captured, while captured stderr and the final stage's captured stdout count against their respective stage limits.

### Timeout & Cancellation

- A command override replaces the context default. For a pipeline, the shortest resolved non-`nil` stage timeout governs the whole pipeline.
- Timeout and task cancellation terminate registered processes immediately with `SIGKILL`, then throw `ShellError.timeout` or `ShellError.canceled` with captured partial output. They do not use the configurable graceful teardown strategy reserved for explicitly spawned processes.
- `run()` does not inherit or accept interactive stdin. A single command's stdin is closed; the first pipeline stage receives no input, and later stages receive the preceding stage's stdout.

### Deferred Workflow Semantics

- Typed workflow steps queue operations until `run()` is awaited.
- `map` and `require` transformations do not trigger execution.
- `run()` is declared `consuming`, but `Workflow` is a copyable value that stores a reusable closure. A workflow value can be copied or run again; each run starts the described operation again.
- Concurrent runs are permitted by the `Sendable` API, but callers remain responsible for whether the underlying operation and external tool can safely run concurrently.

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

`MockExecutor` mirrors built-in `run()` semantics for invalid configuration and non-zero exits. Its caller-supplied handler can also throw arbitrary errors.

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
- Additional typed command families
- Windows support
- Alternative packaging if command families grow substantially
