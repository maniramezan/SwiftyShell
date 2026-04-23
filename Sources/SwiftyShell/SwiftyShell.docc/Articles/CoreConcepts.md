# Core Concepts

Understand the building blocks every SwiftyShell program relies on: the shell context, commands, output, and pipelines.

## Overview

SwiftyShell has a small set of core primitives that every typed command family builds on. Understanding them lets you configure execution correctly, read results reliably, and compose operations into pipelines.

## Shell Context

``ShellContext`` is the execution infrastructure object you pass to every command. It holds:

| Property | Default | Purpose |
|---|---|---|
| `executor` | ``SubprocessExecutor`` | Runs commands; swap with ``MockExecutor`` in tests |
| `searchPaths` | Platform `PATH` | Where executables are resolved |
| `environment` | Inherited from the process | Base env vars for every command |
| `workingDirectory` | `nil` (inherits from the process) | Default directory for commands |
| `defaultTimeout` | `nil` (unlimited) | Seconds before ``ShellError/timeout(command:duration:partialOutput:)`` is thrown |
| `defaultOutputLimit` | `10_485_760` (10 MB) | Bytes before ``ShellError/outputLimitExceeded(command:limit:partialOutput:)`` is thrown |

### Creating a Context

```swift
import SwiftyShell

// Most programs share one context
let context = ShellContext()

// With defaults customised for a long-running build script
let buildContext = ShellContext(
    workingDirectory: "/var/app",
    defaultTimeout: 120,
    defaultOutputLimit: 50_000_000   // 50 MB for verbose build output
)
```

### Override Precedence

Per-command overrides take priority over context defaults, which take priority over platform defaults:

```swift
let context = ShellContext(defaultTimeout: 30)

// This call times out after 300 s, not 30 s
try await Command("swift", "build")
    .timeout(300)
    .run(in: context)

// This call still uses the 30-second context default
try await Command("swift", "package", "resolve").run(in: context)
```

### Customising the Search Path

If an executable lives outside the default `PATH` — common with Homebrew on Apple Silicon or tools installed into non-standard locations — extend the search paths:

```swift
let context = ShellContext(
    searchPaths: ShellContext.defaultSearchPaths + ["/opt/homebrew/bin"]
)
```

Or point a single command at an absolute path without changing the context:

```swift
try await Command("my-tool")
    .executable("/usr/local/bin/my-tool")
    .run(in: context)
```

### Sharing a Context in Tests

All commands that use the same context share the same executor. This is critical in tests — inject ``MockExecutor`` once and every typed family or raw ``Command`` backed by that context uses the mock:

```swift
let mock = MockExecutor(stdout: "on main\n")
let context = ShellContext(executor: mock)

// Both calls go through the mock — no real processes spawned
let status = try await Git(context: context).status().run()
let output = try await Command("echo", "hello").run(in: context)
```

## Commands

``Command`` is the fundamental unit of execution. Every typed command family produces a ``Command`` internally and runs it through the context's executor.

### Fluent Builder

Build a command by naming the executable and chaining modifier methods. Each modifier returns a new copy — ``Command`` is immutable:

```swift
let cmd = Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .workingDirectory("/var/app")
    .timeout(300)
    .stdout(.file(path: "/var/log/deploy.log", append: true))
```

Call `run(in:)` to execute it:

```swift
try await cmd.run(in: context)
```

### Argument Safety

Arguments are an array, not a shell string. SwiftyShell never invokes a shell interpreter — arguments with spaces, quotes, or special characters are passed verbatim to the process:

```swift
// Safe: the space in "/tmp/My Project" is one argument, not two
try await Command("ls", "-la", "/tmp/My Project").run(in: context)

// This would be wrong with a shell string; here it works correctly
try await Command("grep", "-r", "TODO: fix this", "Sources/").run(in: context)
```

### Output Destinations

Control where each stream goes using ``OutputDestination``:

```swift
// Capture (default) — stdout and stderr come back in ShellOutput
let output = try await Command("ls").run(in: context)
print(output.stdout)

// Discard — throw the stream away
try await Command("brew", "update")
    .stderr(.discard)
    .run(in: context)

// File — write stdout to a log; append stderr to the same log
try await Command("swift", "build", "--verbose")
    .stdout(.file(path: "/tmp/build.log", append: false))
    .stderr(.file(path: "/tmp/build.log", append: true))
    .run(in: context)
```

## Shell Output

``ShellOutput`` captures the result of running a command or pipeline:

```swift
let output = try await Command("git", "rev-parse", "HEAD").run(in: context)

// Inspect the result
if output.isSuccess {
    let sha = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    print("HEAD is", sha)
} else {
    print("git failed:", output.stderr, "exit code:", output.exitCode)
}
```

> Note: Typed command families (``Git``, ``Brew``, etc.) throw ``ShellError/exitFailure(command:output:)`` on non-zero exit codes, so you typically only inspect ``ShellOutput`` directly when working with raw ``Command`` calls.

## Pipelines

``Pipeline`` connects commands with Unix pipes. Build one by calling ``Command/pipe(to:)`` on the first command, then chain additional stages:

```swift
// ls -la | grep .swift | wc -l
let count = try await Command("ls", "-la")
    .pipe(to: Command("grep", ".swift"))
    .pipe(to: Command("wc", "-l"))
    .run(in: context)

print(count.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
```

Typed command families hand back a raw ``Command`` via ``RunnableCommandFamily/command()``, so you can use them as pipeline stages without leaving the typed world:

```swift
// List only Swift source files with line numbers
let result = try await Command("ls", "-la")
    .pipe(to: Grep(".swift", context: context).command())
    .run(in: context)
```

The final stage's stdout is returned as ``ShellOutput``. Earlier stages' stdout feeds into the next stage's stdin.

## Executor Protocol

The ``CommandExecutor`` protocol is the seam between SwiftyShell's API and the process that actually runs. Swapping the executor is how testing works:

```swift
public protocol CommandExecutor: Sendable {
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput
    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
}
```

``SubprocessExecutor`` is the default production executor. ``MockExecutor`` is the test double. You can also implement your own — for example, to add structured logging around every command:

```swift
struct LoggingExecutor: CommandExecutor {
    let inner: any CommandExecutor

    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        print("[exec]", command.displayString())
        return try await inner.execute(command, in: context)
    }

    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
        print("[pipe]", pipeline.description)
        return try await inner.execute(pipeline, in: context)
    }
}

let context = ShellContext(executor: LoggingExecutor(inner: SubprocessExecutor()))
```
