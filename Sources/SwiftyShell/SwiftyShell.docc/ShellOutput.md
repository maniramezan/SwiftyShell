# ``ShellOutput``

Captured text and exit status from a command or pipeline.

## Overview

Successful `run()` calls return ``ShellOutput`` with UTF-8 stdout, stderr, and the process exit code:

```swift
let output = try await Command("git", arguments: "rev-parse", "HEAD").run(in: context)
let revision = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
```

The built-in executors throw ``ShellError/exitFailure(command:output:)`` for a non-zero exit from both raw ``Command`` calls and typed command families. Inspect the output associated with that error for failed-process diagnostics:

```swift
do {
    try await Command("git", arguments: "diff", "--exit-code").run(in: context)
} catch ShellError.exitFailure(_, let output) {
    print(output.exitCode, output.stderr)
}
```

Only captured streams appear in this value. ``OutputDestination/file(path:append:)`` and ``OutputDestination/discard`` leave the corresponding field empty, while ``OutputDestination/tee`` both emits the stream live and retains it. Partial outputs attached to timeout, cancellation, and output-limit errors use `-1` when no normal process exit code is available.

## Topics

### Creating Output

- ``init(stdout:stderr:exitCode:)``

### Inspecting Output

- ``stdout``
- ``stderr``
- ``exitCode``
- ``isSuccess``
