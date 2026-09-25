# ``ShellError``

Built-in errors reported while running shell commands and workflow gates.

## Overview

Built-in execution failures from typed command families, raw ``Command`` calls,
``Pipeline`` stages, and built-in ``Workflow`` gates surface as ``ShellError``.
Match on a specific case rather than testing exit codes or parsing stderr strings;
the cases are stable, the messages inside them are not. Custom executors, workflow
closures and transforms, and custom gate errors can throw other `Error` values.
Structured command workflows report successful commands with malformed output as
``parsingError(command:reason:)-enum.case`` rather than silently returning an empty result.

The most common shape is a `do/catch` that handles the specific failures you
care about and lets the rest propagate:

```swift
do {
    try await Git(context: context)
        .workingDirectory(repoPath)
        .pull()
        .run()
} catch ShellError.commandNotFound(let cmd) {
    print("\(cmd) is not installed")
} catch ShellError.exitFailure(_, let output) {
    print("Pull failed:", output.stderr)
} catch ShellError.timeout(let cmd, let duration, _) {
    print("\(cmd) timed out after \(duration)s")
}
```

The cases group naturally by failure source:

- **Configuration errors** — ``invalidConfiguration(description:)`` is thrown
  before any process spawns when a timeout is negative or non-finite, or when
  an output limit is negative.
- **Execution errors** — ``commandNotFound(_:)``, ``spawnError(command:reason:)-enum.case``,
  and ``exitFailure(command:output:)-enum.case`` cover the lifecycle of finding,
  launching, and waiting on a subprocess.
- **Resource errors** — ``timeout(command:duration:partialOutput:)-enum.case`` and
  ``outputLimitExceeded(command:limit:partialOutput:)-enum.case`` carry the captured
  output up to the point the process or pipeline was terminated.
- **Stream errors** — ``decodingError(command:stream:)-enum.case`` is raised when a typed
  workflow that parses stdout (such as `Git` status or `Which` lookup) receives
  bytes that are not valid UTF-8. Plain `run()` calls never throw it: they keep
  the raw bytes in ``ShellOutput/stdoutData``.
- **Parsing errors** — ``parsingError(command:reason:)-enum.case`` is raised when a
  typed workflow receives valid text that does not match the expected structured
  output shape.
- **Task and workflow errors** — ``canceled(command:partialOutput:)-enum.case`` is
  raised when the surrounding `Task` is canceled and carries partial output, and
  ``workflowConditionFailed(description:)`` when a ``Workflow/require(_:else:)-swift.method``
  predicate returns `false`.

For a complete walkthrough — including each case's recovery strategy — see
<doc:ErrorHandling>.

## Topics

### Configuration Error

- ``invalidConfiguration(description:)``

### Execution Errors

- ``commandNotFound(_:)``
- ``exitFailure(command:output:)-enum.case``
- ``spawnError(command:reason:)-enum.case``

### Resource Errors

- ``timeout(command:duration:partialOutput:)-enum.case``
- ``outputLimitExceeded(command:limit:partialOutput:)-enum.case``

### Stream Error

- ``decodingError(command:stream:)-enum.case``

### Parsing Error

- ``parsingError(command:reason:)-enum.case``

### Task Error

- ``canceled(command:partialOutput:)-enum.case``

### Workflow Error

- ``workflowConditionFailed(description:)``

### Creating Errors from Display Text

For custom executors that only have a display string; the resulting
``CommandSnapshot`` has no argv.

- ``exitFailure(command:output:)-swift.type.method``
- ``timeout(command:duration:partialOutput:)-swift.type.method``
- ``outputLimitExceeded(command:limit:partialOutput:)-swift.type.method``
- ``canceled(command:partialOutput:)-swift.type.method``
- ``spawnError(command:reason:)-swift.type.method``
- ``decodingError(command:stream:)-swift.type.method``
- ``parsingError(command:reason:)-swift.type.method``

### Related Types

- ``StreamKind``
- ``CommandSnapshot``
