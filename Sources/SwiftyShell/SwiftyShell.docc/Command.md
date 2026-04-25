# ``Command``

A value describing a single shell command and its execution overrides.

## Overview

``Command`` is the fluent escape hatch for tools that don't have a typed wrapper
yet. It uses the same builder shape as every typed command family — chain
modifiers to add arguments, environment variables, a working directory, a
timeout, an output limit, and stdout/stderr destinations, then call
``run(in:)`` to execute it inside a ``ShellContext``.

Each modifier returns a new copy; ``Command`` itself is an immutable, `Sendable`
value, so it is safe to store, share across tasks, and pass into structured
concurrency.

The simplest call is just an executable name and arguments:

```swift
let context = ShellContext()
let output = try await Command("echo", "Hello, SwiftyShell!").run(in: context)
print(output.stdout)
```

For longer-running tools, layer on overrides for environment, working
directory, and timeout:

```swift
try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .workingDirectory("/var/app")
    .timeout(300)
    .run(in: context)
```

When you want to redirect output to a file instead of capturing it, use
``OutputDestination/file(path:append:)`` on ``stdout(_:)`` and ``stderr(_:)``:

```swift
try await Command("swift", "build", "--verbose")
    .stdout(.file(path: "/tmp/build.log", append: false))
    .stderr(.file(path: "/tmp/build.log", append: true))
    .run(in: context)
```

To compose with other commands, use ``pipe(to:)`` to build a ``Pipeline``.

## Topics

### Creating a Command

- ``init(_:_:)``

### Adding Arguments

- ``arg(_:)``
- ``args(_:)``

### Configuring the Executable

- ``executable(_:)``

### Setting the Environment

- ``env(_:_:)``
- ``env(_:)``

### Constraining Execution

- ``workingDirectory(_:)``
- ``timeout(_:)``
- ``outputLimit(_:)``

### Redirecting Output

- ``stdout(_:)``
- ``stderr(_:)``

### Running

- ``run(in:)``

### Piping

- ``pipe(to:)``

### Inspecting

- ``executableName``
- ``arguments``
- ``executableOverride``
- ``environmentOverrides``
- ``workingDirectoryOverride``
- ``timeoutOverride``
- ``outputLimitOverride``
- ``stdoutDestination``
- ``stderrDestination``
- ``displayString(using:)``
