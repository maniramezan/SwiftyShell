# ``ProcessTeardownStep``

One signal-and-delay step in a spawned-process teardown sequence.

## Overview

Use ``ProcessTeardownStep`` to build custom ``TeardownStrategy`` values. Each
step sends a ``ProcessSignal`` and then waits the associated grace period before
moving on to the next step.

```swift
let strategy = TeardownStrategy(steps: [
    ProcessTeardownStep(signal: .interrupt, gracePeriod: .seconds(3)),
    ProcessTeardownStep(signal: .terminate, gracePeriod: .seconds(1)),
])
```

SwiftyShell's subprocess backend appends a final kill step after the configured
graceful sequence, so custom strategies still eventually guarantee cleanup.

## Topics

### Creating a Step

- ``init(signal:gracePeriod:)``

### Inspecting

- ``signal``
- ``gracePeriod``
