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

### Progress alongside JSON

Choose the parent stream explicitly with ``teeTo(_:)``. Captured stdout and stderr remain separate,
even when both live streams go to the parent's stderr:

```swift
let output = try await Command("xcodebuild", arguments: "build")
    .stdout(.teeTo(.stderr))
    .stderr(.teeTo(.stderr))
    .run(in: context)
// The parent can now write a JSON result to stdout without mixing in build progress.
```

### Complete logs with bounded memory

Use ``log(path:append:tailBytes:tee:)`` to write all received bytes to a log file and retain only the
last bytes for diagnostics. Filling the tail does not fail or terminate the command:

```swift
let output = try await Command("./gradlew", arguments: "assembleRelease")
    .stdout(.log(path: "build.stdout.log", append: false, tailBytes: 65_536, tee: .stderr))
    .stderr(.log(path: "build.stderr.log", append: false, tailBytes: 65_536, tee: .stderr))
    .run(in: context)
```

Paths resolve against the command's working directory. Parent directories must already exist.
A zero-byte tail writes the log without retaining output. Negative tail sizes throw
``ShellError/invalidConfiguration(description:)`` before execution. Both streams can append to the
same file; using a shared path with either stream in overwrite mode is rejected. Ordering between
stdout and stderr depends on when their bytes arrive; it is not a total ordering of child writes.

Retained tail bytes still count toward the command's shared hard ``Command/outputLimit(_:)``.
Set that limit to at least the sum of the desired tails, accounting for any other captured stream.
Tail sizes count bytes, not characters: a tail can start inside a UTF-8 sequence. Use
``ShellOutput/stdoutData`` and ``ShellOutput/stderrData`` for exact bytes.

Failure, timeout, and cancellation errors contain the retained tails. The file contains bytes
received before execution stops; background descendants' output after the leader exits is not
collected. File writes are not fsynced, and the log does not imply durable storage after a crash.
In pipelines, only the final stage's stdout is routed this way; every stage can route its stderr.
For spawned processes, live streams still contain full chunks, while retained tails require
`spawn(captureOutput: true)`. ``MockExecutor`` trims supplied log output in memory and never writes
log files or parent streams; it does not simulate live timing or enforce byte-limit overflows.

## Topics

### Destinations

- ``capture``
- ``tee``
- ``teeTo(_:)``
- ``log(path:append:tailBytes:tee:)``
- ``file(path:append:)``
- ``discard``
