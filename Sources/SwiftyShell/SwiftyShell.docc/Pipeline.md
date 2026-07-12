# ``Pipeline``

A sequence of commands connected by OS pipes.

## Overview

Build a ``Pipeline`` with ``Command/pipe(to:)``. SwiftyShell starts every stage concurrently, closes stdin for the first stage, and connects each stage's stdout to the next stage's stdin without asking a shell to parse a pipeline string.

```swift
let output = try await Command("printf", arguments: "alpha\nbeta\n")
    .pipe(to: Command("grep", arguments: "beta"))
    .pipe(to: Command("wc", arguments: "-l"))
    .run(in: context)
```

On success, ``ShellOutput/stdout`` contains the final stage's captured stdout. Captured stderr from all stages is concatenated in stage order. Intermediate stdout is carried by the pipe rather than captured.

Each stage resolves its own ``Command/outputLimit(_:)``. A stage's captured stderr and the final stage's captured stdout count against that stage's limit. The shortest resolved non-`nil` stage timeout governs the whole pipeline.

If a stage exits non-zero, the built-in executor reports an observed failing stage through ``ShellError/exitFailure(command:output:)`` and cancels the remaining stage tasks. Because stages are concurrent, simultaneous failures do not have a deterministic pipeline-order winner. Timeout, cancellation, and output-limit failures include captured partial output.

## Topics

### Composing

- ``stages``
- ``pipe(to:)``

### Running

- ``run(in:)``
