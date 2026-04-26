# Error Handling

Catch the right ``ShellError`` case for every failure mode SwiftyShell can produce.

## Overview

All failures in SwiftyShell surface as ``ShellError``. Never test stderr strings or exit codes to decide what went wrong — match on the specific enum case instead. This keeps call sites readable and makes them resilient to message changes in the underlying tools.

```swift
do {
    try await Git(context: context)
        .workingDirectory(repoPath)
        .pull()
        .run()
} catch ShellError.commandNotFound(let cmd) {
    // git is not on the search path
    print("\(cmd) is not installed")
} catch ShellError.exitFailure(_, let output) {
    // git exited with a non-zero code (merge conflict, network error, …)
    print("Pull failed:", output.stderr)
} catch ShellError.timeout(let cmd, let duration, _) {
    // the command exceeded its configured time limit
    print("\(cmd) timed out after \(duration)s")
}
```

## Error Cases

### Configuration Errors

#### `invalidConfiguration`

Thrown *before* launching a process when a timeout or output-limit value is negative. Fix the value at the call site that constructed it.

```swift
// Throws immediately — negative timeout is invalid
try await Command("ls")
    .timeout(-1)
    .run(in: context)
```

### Execution Errors

#### `commandNotFound`

The executable name could not be resolved to an absolute path using the context's ``ShellContext/searchPaths``. Common causes: the tool is not installed, or it lives in a non-standard location.

```swift
do {
    try await Command("my-tool").run(in: context)
} catch ShellError.commandNotFound(let name) {
    print("\(name) not found — check ShellContext.searchPaths or use .executable(_:)")
}
```

To target an absolute path, use ``Command/executable(_:)`` instead of relying on search paths:

```swift
try await Command("my-tool")
    .executable("/opt/local/bin/my-tool")
    .run(in: context)
```

#### `exitFailure`

The process ran and exited with a non-zero status code. The associated ``ShellOutput`` contains any captured stdout and stderr produced before exit.

```swift
do {
    try await Command("swift", arguments: "test").run(in: context)
} catch ShellError.exitFailure(let cmd, let output) {
    print("\(cmd) failed with exit code \(output.exitCode)")
    print(output.stderr)
}
```

#### `spawnError`

The operating system could not create the subprocess — for example, because the file is not executable, resource limits are exhausted, or the executable path does not exist.

```swift
do {
    try await Command("my-tool")
        .executable("/path/to/my-tool")
        .run(in: context)
} catch ShellError.spawnError(let cmd, let reason) {
    print("Could not launch \(cmd): \(reason)")
}
```

### Resource Errors

#### `timeout`

The command ran longer than the configured limit. The ``ShellError/timeout(command:duration:partialOutput:)`` case carries any output captured up to the point the process was terminated.

```swift
let context = ShellContext(defaultTimeout: 30)

do {
    try await Command("curl", arguments: "https://example.com/large-file").run(in: context)
} catch ShellError.timeout(let cmd, let duration, let partial) {
    print("\(cmd) timed out after \(duration)s")
    print("Partial stdout:", partial.stdout.prefix(200))
}
```

Per-command overrides let you relax the limit for one call without changing the context:

```swift
// Inherits the 30-second context default
try await Command("swift", arguments: "package", "resolve").run(in: context)

// Needs more time — override for this call only
try await Command("swift", arguments: "test", "--filter", "CommandTests")
    .timeout(600)
    .run(in: context)
```

#### `outputLimitExceeded`

The accumulated captured output exceeded the configured limit. Like `timeout`, the partial output captured so far is included. Increase the limit via ``Command/outputLimit(_:)`` or redirect output to a file with ``OutputDestination/file(path:append:)``.

```swift
// Redirect verbose output to a file instead of capturing it
try await Command("swift", arguments: "build", "--verbose")
    .stdout(.file(path: "/tmp/build.log", append: false))
    .stderr(.file(path: "/tmp/build.log", append: true))
    .run(in: context)
```

### Stream Errors

#### `decodingError`

The captured output could not be decoded as UTF-8. This happens with binary output (e.g. compiled artifacts, compressed archives). Use ``OutputDestination/file(path:append:)`` to write such output to a file and read it as `Data` yourself.

### Task and Workflow Errors

#### `cancelled`

The Swift `Task` enclosing the `run()` call was cancelled. SwiftyShell sends SIGTERM then SIGKILL to the subprocess and rethrows as `ShellError.cancelled`. The partial output captured so far is attached.

```swift
let task = Task {
    try await Command("long-running-tool").run(in: context)
}

// … later:
task.cancel()
// The task throws ShellError.cancelled(command:partialOutput:)
```

Standard Swift structured-concurrency cancellation (`withTaskCancellationHandler`, task groups, `Task.checkCancellation()`) also propagates automatically.

#### `workflowConditionFailed`

A ``Workflow/require(_:else:)-swift.method`` or ``Workflow/require(_:equals:else:)`` predicate returned `false`. The description is either the message from the custom error you passed as the `else` argument, or the default "Git workflow condition failed" message.

```swift
do {
    try await Git(context: context)
        .workingDirectory(repoPath)
        .status()
        .require(\.state, equals: .noChanges)
        .pull()
        .run()
} catch ShellError.workflowConditionFailed(let description) {
    print("Precondition not met:", description)
}
```

## Catching All Errors

Match specific cases first, then fall through to a generic handler to avoid silent swallowing of unexpected failures:

```swift
do {
    try await someWorkflow.run()
} catch ShellError.commandNotFound(let cmd) {
    // Specific: tool not installed
} catch ShellError.exitFailure(_, let output) {
    // Specific: non-zero exit
    print(output.stderr)
} catch let error as ShellError {
    // Everything else (timeout, cancelled, …)
    print("Unexpected shell error:", error)
} catch {
    // Non-ShellError failures (e.g. from your own workflow code)
    print("Error:", error)
}
```

## Error Reference Table

| Case | Cause | Recovery |
|---|---|---|
| `invalidConfiguration` | Negative timeout or output limit | Fix the configuration value |
| `commandNotFound` | Executable not on search path | Check `searchPaths` or use `.executable(_:)` |
| `exitFailure` | Non-zero exit code | Inspect `output.stderr`; retry or abort |
| `spawnError` | OS could not create process | Check executable path and permissions |
| `timeout` | Exceeded time limit | Inspect `partialOutput`; increase limit or redirect to file |
| `outputLimitExceeded` | Output exceeded limit | Increase `outputLimit` or redirect to file |
| `decodingError` | Output is not valid UTF-8 | Redirect to file; read as `Data` |
| `cancelled` | Parent Swift task was cancelled | Inspect `partialOutput`; propagate cancellation |
| `workflowConditionFailed` | A `require` predicate returned false | Handle the specific gate condition |
