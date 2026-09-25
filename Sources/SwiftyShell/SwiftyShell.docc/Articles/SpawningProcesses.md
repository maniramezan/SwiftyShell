# Spawning Processes

Start and control long-running shell commands from Swift.

## Overview

Most shell commands should use ``Command/run(in:)``. It starts the process,
captures output, waits for exit, and throws ``ShellError`` for failure modes.

Use ``Command/spawn(in:teardown:)`` when the command is intentionally
long-running and must be controlled later. Common examples are local servers,
file watchers, log streams, recorders, and test hosts.

```swift
let server = try await Command("python3", arguments: "-m", "http.server", "8080")
    .spawn()

// ... interact with the server ...

let output = await server.teardownAndWait()
```

## Stream Output

Spawned processes expose stdout and stderr as async streams of text
(``SpawnedProcess/standardOutput``) and of raw bytes
(``SpawnedProcess/standardOutputData``, for binary output). By default the output
is only streamed, not retained, so a long-running server cannot grow memory over
its lifetime; ``SpawnedProcess/waitForExit()`` and
``SpawnedProcess/teardownAndWait()`` then report the exit code with empty output.

```swift
let process = try await Command("long-running-tool").spawn()

Task {
    for await chunk in process.standardOutput {
        print(chunk, terminator: "")
    }
}
```

Chunks have arbitrary sizes and are not split on line boundaries, but a text chunk
never ends in the middle of a multi-byte UTF-8 character. Each stream keeps the
1,024 most recent chunks you have not read yet and drops older ones, so an unread
stream cannot grow without limit.

When the final output matters (for example a build you also want to parse), pass
`captureOutput: true`. Captured streams are then kept up to the configured
``Command/outputLimit(_:)`` or ``ShellContext/defaultOutputLimit``, and exceeding
that limit tears the process down:

```swift
let build = try await Command("swift", arguments: "build").spawn(captureOutput: true)
for await chunk in build.standardOutput {
    print(chunk, terminator: "")
}
let output = await build.waitForExit()  // output.stdout holds the full log
```

## Choose a Teardown Strategy

``TeardownStrategy/graceful`` is the default. It sends `SIGTERM`, waits five
seconds, then relies on the subprocess backend's final kill step if the process
does not exit.

Every teardown signal, including the final kill, goes to the spawned process's
process group, so descendants started by wrappers such as `sh -c` or `npm run`
are stopped too.

```swift
let server = try await Command("server").spawn(teardown: .graceful)
let output = await server.teardownAndWait()
```

Use ``TeardownStrategy/interruptThenTerminate`` for tools that finalize output
on `SIGINT`, such as screen recorders.

```swift
let recorder = try await Command("record-video").spawn(teardown: .interruptThenTerminate)
let output = await recorder.teardownAndWait()
```

Use ``TeardownStrategy/immediate`` when no graceful cleanup is needed.

## Wait Without Signaling

Call ``SpawnedProcess/waitForExit()`` when the process is expected to exit on
its own.

```swift
let process = try await Command("worker").spawn()
let output = await process.waitForExit()
```

For processes that run forever, call ``SpawnedProcess/teardownAndWait()`` or send
a signal explicitly before waiting.

## Test Spawning Code

``MockExecutor`` implements spawn by returning ``MockSpawnedProcess``. Tests can
assert signal history and teardown behavior without launching a real process.

```swift
let context = ShellContext(executor: MockExecutor(stdout: "ready\n"))
let process = try await Command("server").spawn(in: context)

try await process.interrupt()
let output = await process.waitForExit()
```

## Linux Notes

SwiftyShell supports spawn on macOS and Linux. Signals are delivered through the
underlying subprocess execution handle, which uses process descriptors on Linux
when available. This avoids relying on a bare process identifier for normal
signal delivery.
