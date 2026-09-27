# ``MockExecutor``

A test-double implementation of ``CommandExecutor`` that returns caller-controlled responses without spawning real processes.

## Overview

`MockExecutor` is the testing seam for SwiftyShell. Inject one through
``ShellContext/init(executor:searchPaths:environment:workingDirectory:defaultTimeout:defaultOutputLimit:)-(_,_,_,_,Duration?,_)``
and every command — typed or raw — that runs in that context goes through the
mock instead of spawning a real subprocess. The mock mirrors the real executor's
failure semantics (non-zero exit codes throw ``ShellError/exitFailure(command:output:)``,
configuration validation runs before the response is returned), so tests assert
the same code paths production runs.

For simple scenarios, return a fixed ``ShellOutput`` for every call:

```swift
@Test func buildReturnsMockedOutput() async throws {
    let mock = MockExecutor(stdout: "Build complete.\n")
    let context = ShellContext(executor: mock)

    let output = try await Command("swift", arguments: "build").run(in: context)

    #expect(output.stdout == "Build complete.\n")
}
```

Every mock records the commands it receives, so a test can assert exactly what
ran without writing its own recorder:

```swift
@Test func deployRunsMigrationsBeforeRestart() async throws {
    let mock = MockExecutor()
    try await deploy(context: ShellContext(executor: mock))

    #expect(mock.recordedCommands.map(\.arguments) == [
        ["db:migrate"],
        ["restart", "web"],
    ])
}
```

Use stubs to answer different commands differently. Stubs are checked in order,
so list specific ones first. A command that matches no stub throws
``ShellError/commandNotFound(_:)`` (with the executable name, as a missing
binary does) unless you pass a `fallback`, which keeps
unexpected commands from passing silently:

```swift
let mock = MockExecutor(stubs: [
    .init("git", arguments: ["rev-parse", "HEAD"], returning: ShellOutput(stdout: "abc123\n", exitCode: 0)),
    .init("git", returning: ShellOutput(stderr: "unexpected git call", exitCode: 1)),
    .init(matching: { $0.workingDirectoryOverride == "/tmp" }, returning: ShellOutput(exitCode: 0)),
])
```

For arbitrary logic, supply a handler closure that inspects the incoming
``Command`` and ``ShellContext``:

```swift
let mock = MockExecutor { command, _ in
    if command.executableName == "git" {
        return ShellOutput(stdout: "on main\n", stderr: "", exitCode: 0)
    }
    return ShellOutput(stdout: "", stderr: "unsupported", exitCode: 1)
}
```

Pipelines follow the production executor's semantics: every stage's
configuration is validated first, every stage is invoked, the result has the
final stage's stdout and every stage's stderr in order, and the first failing
stage in pipeline order is reported through
``ShellError/exitFailure(command:output:)``. As in production, a non-final
stage that reports `128 + SIGPIPE` is not a failure. The mock does not feed one
stage's stdout into the next.

To exercise error paths, return a non-zero exit code — typed families and raw
``Command`` calls both throw ``ShellError/exitFailure(command:output:)`` exactly
as they do in production:

```swift
let mock = MockExecutor(stdout: "", stderr: "fatal: not a repo", exitCode: 128)
let context = ShellContext(executor: mock)

await #expect(throws: ShellError.self) {
    try await Git(context: context).status().run()
}
```

## Topics

### Creating a Mock Executor

- ``init(handler:)``
- ``init(stdout:stderr:exitCode:)``
- ``init(stubs:fallback:)``
- ``Stub``

### Inspecting Calls

- ``recordedCommands``

### Executing

- ``execute(_:in:)-(Command,_)``
- ``execute(_:in:)-(Pipeline,_)``

### Related Types

- ``CommandExecutor``
- ``ShellOutput``
