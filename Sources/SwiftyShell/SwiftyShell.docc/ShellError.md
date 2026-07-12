# ``ShellError``

Built-in errors reported while running shell commands and workflow gates.

## Overview

Built-in execution failures from typed command families, raw ``Command`` calls,
``Pipeline`` stages, and built-in ``Workflow`` gates surface as ``ShellError``.
Match on a specific case rather than testing exit codes or parsing stderr strings;
the cases are stable, the messages inside them are not. Custom executors, workflow
closures and transforms, and custom gate errors can throw other `Error` values.
Structured command workflows report successful commands with malformed output as
``parsingError(command:reason:)`` rather than silently returning an empty result.

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
- **Execution errors** — ``commandNotFound(_:)``, ``spawnError(command:reason:)``,
  and ``exitFailure(command:output:)`` cover the lifecycle of finding,
  launching, and waiting on a subprocess.
- **Resource errors** — ``timeout(command:duration:partialOutput:)`` and
  ``outputLimitExceeded(command:limit:partialOutput:)`` carry the captured
  output up to the point the process or pipeline was terminated.
- **Stream errors** — ``decodingError(command:stream:)`` is raised when output
  is not valid UTF-8. Redirect to a file with
  ``OutputDestination/file(path:append:)`` and read it as `Data` instead.
- **Parsing errors** — ``parsingError(command:reason:)`` is raised when a
  typed workflow receives valid text that does not match the expected structured
  output shape.
- **Task and workflow errors** — ``canceled(command:partialOutput:)`` is
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
- ``exitFailure(command:output:)``
- ``spawnError(command:reason:)``

### Resource Errors

- ``timeout(command:duration:partialOutput:)``
- ``outputLimitExceeded(command:limit:partialOutput:)``

### Stream Error

- ``decodingError(command:stream:)``

### Parsing Error

- ``parsingError(command:reason:)``

### Task Error

- ``canceled(command:partialOutput:)``

### Workflow Error

- ``workflowConditionFailed(description:)``

### Related Types

- ``StreamKind``
