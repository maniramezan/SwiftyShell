# ``ShellOutput``

Captured bytes, text, and exit status from a command or pipeline.

## Overview

Successful `run()` calls return ``ShellOutput`` with the captured stdout and stderr bytes and the process exit code. ``stdout`` and ``stderr`` decode those bytes as UTF-8:

```swift
let output = try await Command("git", arguments: "rev-parse", "HEAD").run(in: context)
let revision = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
```

Binary output is kept unchanged in ``stdoutData`` and ``stderrData``:

```swift
let archive = try await Command("tar", arguments: "-cz", "Sources").run(in: context)
try archive.stdoutData.write(to: URL(fileURLWithPath: "sources.tgz"))
```

The text views replace invalid UTF-8 with U+FFFD. Use ``validatedText(_:)`` when invalid bytes must be detected instead; it returns `nil` rather than replacing them.

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
- ``init(stdoutData:stderrData:exitCode:)``

### Inspecting Output

- ``stdout``
- ``stderr``
- ``stdoutData``
- ``stderrData``
- ``validatedText(_:)``
- ``exitCode``
- ``isSuccess``
