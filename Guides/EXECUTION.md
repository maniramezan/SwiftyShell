# Execution behavior

SwiftyShell models each process invocation as values. `Command` stores an executable and separate arguments; `Pipeline` connects commands with operating-system pipes; `Workflow` composes asynchronous operations and gates.

## Running commands

`Command.run()` uses `SubprocessExecutor` by default. It returns captured output after the process exits. Commands receive empty standard input by default. Choose `InputSource` and `OutputDestination` values to provide input or capture, tee, discard, or redirect output.

```swift
let output = try await Command("jq", arguments: ".name")
    .stdin(.string("{\"name\":\"Ada\"}"))
    .run()
```

The [Command API reference](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/command) and [Core Concepts tutorial](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/coreconcepts) cover command construction, input, output, and pipelines.

## Errors, timeouts, and cancellation

Built-in execution failures use `ShellError`. Set a timeout on a command or in `ShellContext`. Timeout, output-limit failure, and task cancellation tear down the process group, and errors preserve captured partial output when available.

```swift
do {
    try await Command("long-running-tool")
        .timeout(.seconds(5))
        .run()
} catch ShellError.timeout(_, _, let partial) {
    print("Captured before timeout:", partial.stdout)
}
```

See the DocC [Error Handling guide](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/errorhandling) for error cases and recovery patterns.

## Spawned processes

Use `spawn()` when the caller needs live output streams, signal control, or a configurable teardown sequence. Plain `spawn()` streams output without retaining it; use `spawn(captureOutput: true)` when the final output should also be returned by `waitForExit()` or `teardownAndWait()`.

See the DocC [Spawning Processes tutorial](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/spawningprocesses) for examples.

## Security boundary

Separate argv entries prevent shell splitting, but SwiftyShell does not validate tool-specific syntax. Treat executable names, raw options, paths, environment values, interpreter strings, and expressions as caller-controlled input. Use fixed executables and allowlisted options in privileged automation.
