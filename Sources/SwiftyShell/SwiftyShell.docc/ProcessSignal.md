# ``ProcessSignal``

A Unix signal that can be sent to a spawned process.

## Overview

SwiftyShell supports macOS and Linux process signaling through
``SpawnedProcess/send(_:)`` and ``TeardownStrategy``. The built-in signals cover
the common lifecycle operations used by shell tools.

```swift
let process = try await Command("long-running-tool").spawn()
try await process.send(.interrupt)
```

## Topics

### Common Signals

- ``interrupt``
- ``terminate``
- ``kill``
- ``hangup``
- ``quit``

### Raw Values

- ``init(rawValue:)``
