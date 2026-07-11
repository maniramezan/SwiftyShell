# ``OutputDestination``

A routing policy for a command's stdout or stderr stream.

## Overview

Set stream routing with ``Command/stdout(_:)`` and ``Command/stderr(_:)``. Capture is the default:

```swift
let output = try await Command("swift", arguments: "build").run(in: context)
print(output.stdout)
```

Use ``tee`` when progress should appear on the parent process's matching stream while remaining available in ``ShellOutput``:

```swift
let output = try await Command("swift", arguments: "test")
    .stdout(.tee)
    .stderr(.tee)
    .run(in: context)
```

Both ``capture`` and ``tee`` count retained bytes toward the output limit. ``file(path:append:)`` writes bytes without retaining them in memory, and ``discard`` drops them. File paths are caller-controlled security-sensitive inputs; constrain untrusted paths before running commands.

## Topics

### Destinations

- ``capture``
- ``tee``
- ``file(path:append:)``
- ``discard``
