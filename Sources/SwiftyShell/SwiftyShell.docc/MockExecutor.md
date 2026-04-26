# ``MockExecutor``

A test-double implementation of ``CommandExecutor`` that returns caller-controlled responses without spawning real processes.

## Overview

`MockExecutor` is the testing seam for SwiftyShell. Inject one through
``ShellContext/init(executor:searchPaths:environment:workingDirectory:defaultTimeout:defaultOutputLimit:)``
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

For richer tests, supply a closure that inspects the incoming ``Command`` and
returns a tailored response. Combine it with an `actor` to record invocations
across concurrent calls:

```swift
actor InvocationRecorder {
    var commands: [Command] = []
    func record(_ command: Command) { commands.append(command) }
}

let recorder = InvocationRecorder()
let mock = MockExecutor { command, _ in
    await recorder.record(command)
    if command.executableName == "git" {
        return ShellOutput(stdout: "on main\n", stderr: "", exitCode: 0)
    }
    return ShellOutput(stdout: "", stderr: "unsupported", exitCode: 1)
}
let context = ShellContext(executor: mock)
```

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

### Executing

- ``execute(_:in:)-(Command,_)``
- ``execute(_:in:)-(Pipeline,_)``

### Related Types

- ``CommandExecutor``
- ``ShellOutput``
