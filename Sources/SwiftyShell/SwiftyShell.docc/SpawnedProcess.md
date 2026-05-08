# ``SpawnedProcess``

A handle to a long-running process started without waiting for completion.

## Overview

Use ``Command/spawn(in:teardown:)`` when a command should keep running while
your Swift code continues, such as a local server, file watcher, recorder, or
test host. A spawned process exposes real-time stdout/stderr streams and can be
signaled or torn down later.

```swift
let server = try await Command("python3", arguments: "-m", "http.server", "8080")
    .spawn()

for await line in server.standardOutput {
    print(line)
}

let output = await server.teardownAndWait()
```

Short-lived commands should use ``Command/run(in:)`` instead.

When you need deterministic shutdown and final output collection, explicitly call
``waitForExit()`` or ``teardownAndWait()``. Releasing the last handle triggers a
best-effort asynchronous teardown using the configured ``TeardownStrategy``, but
that safety path should be treated as fallback cleanup rather than the primary
way to stop a process.

## Topics

### Inspecting

- ``processIdentifier``

### Streaming Output

- ``standardOutput``
- ``standardError``

### Signaling

- ``send(_:)``
- ``interrupt()``
- ``terminate()``

### Waiting

- ``waitForExit()``
- ``teardownAndWait()``
