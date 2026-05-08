# ``TeardownStrategy``

A policy for gracefully stopping a spawned process.

## Overview

``TeardownStrategy`` controls what ``SpawnedProcess/teardownAndWait()`` does
before waiting for process exit. Strategies are ordered signal-and-grace-period
steps. SwiftyShell relies on the subprocess backend to append a final kill step,
so cleanup is eventually guaranteed.

Use ``graceful`` for most long-running commands:

```swift
let process = try await Command("server").spawn(teardown: .graceful)
let output = await process.teardownAndWait()
```

Use ``interruptThenTerminate`` for tools that finalize data on interrupt, such
as screen or video recorders:

```swift
let recorder = try await Command("record-video").spawn(teardown: .interruptThenTerminate)
let output = await recorder.teardownAndWait()
```

## Topics

### Presets

- ``graceful``
- ``interruptThenTerminate``
- ``immediate``

### Custom Strategies

- ``init(steps:)``
- ``steps``
