# ``CommandSnapshot``

The executable and argv of a command that failed, attached to ``ShellError``.

## Overview

Errors from the built-in executor carry a snapshot instead of a plain string, so
you can inspect exactly which binary ran with which arguments without parsing a
display string:

```swift
do {
    try await Command("swift", arguments: "test", "--filter", "Parser Tests").run(in: context)
} catch ShellError.exitFailure(let command, let output) {
    // /usr/bin/swift
    print(command.resolvedExecutable ?? "?")
    // ["test", "--filter", "Parser Tests"]
    print(command.arguments ?? [])
    // /usr/bin/swift test --filter 'Parser Tests'
    print(command)
    print(output.exitCode)
}
```

A snapshot never contains environment values or stdin bytes, so it is safe to log.
Errors created by custom executors from display text (for example
`ShellError.exitFailure(command: "my-tool --flag", output: output)`) produce a
display-only snapshot whose ``executableName`` and ``arguments`` are `nil`.

## Topics

### Creating a Snapshot

- ``init(_:resolvedExecutable:)``
- ``init(displayString:)``

### Inspecting

- ``executableName``
- ``arguments``
- ``resolvedExecutable``
- ``displayString``
