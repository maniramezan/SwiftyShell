# ``Command``

A value describing a single shell command and its execution overrides.

## Overview

``Command`` is the fluent escape hatch for tools that don't have a typed wrapper
yet. It uses the same builder shape as every typed command family — chain
modifiers to add arguments, environment variables, a working directory, a
timeout, an output limit, and stdout/stderr destinations, then call
``run(in:)`` to execute it inside a ``ShellContext`` or
``spawn(in:teardown:)`` to start a long-running process that you control later.

Each modifier returns a new copy; ``Command`` itself is an immutable, `Sendable`
value, so it is safe to store, share across tasks, and pass into structured
concurrency.

The simplest call is just an executable name and arguments:

```swift
let context = ShellContext()
let output = try await Command("echo", arguments: "Hello, SwiftyShell!").run(in: context)
print(output.stdout)
```

For longer-running tools, layer on overrides for environment, working
directory, and timeout:

```swift
try await Command("ruby", arguments: "deploy.rb")
    .env("RAILS_ENV", "production")
    .workingDirectory("/var/app")
    .timeout(.seconds(300))
    .run(in: context)
```

When you want to redirect output to a file instead of capturing it, use
``OutputDestination/file(path:append:)`` on ``stdout(_:)`` and ``stderr(_:)``:

```swift
try await Command("swift", arguments: "build", "--verbose")
    .stdout(.file(path: "/tmp/build.log", append: false))
    .stderr(.file(path: "/tmp/build.log", append: true))
    .run(in: context)
```

Relative executable overrides and output-file paths resolve against the effective working
directory. When stdout and stderr target the same file, use append mode for both streams;
configuring either stream to overwrite the shared file raises
``ShellError/invalidConfiguration(description:)`` to prevent truncation races.

To compose with other commands, use ``pipe(to:)`` to build a ``Pipeline``.

### Displaying Commands

``description`` and ``displayString(using:)`` render the argv with POSIX single quoting: empty
arguments and arguments containing spaces, quotes, `$`, globs, or command separators are quoted,
so the string can be pasted into `sh`, `bash`, or `zsh` to run the same argv.

```swift
let command = Command("git", arguments: "commit", "-m", "it's $HOME")
print(command)  // git commit -m 'it'\''s $HOME'
```

## Topics

### Creating a Command

- ``init(_:arguments:)-(_,String...)``
- ``init(_:arguments:)-(_,[String])``

### Adding Arguments

- ``arg(_:)``
- ``args(_:)``

### Configuring the Executable

- ``executable(_:)``

### Setting the Environment

- ``env(_:_:)``
- ``env(_:)``
- ``unsetEnv(_:)-(String...)``
- ``unsetEnv(_:)-([String])``

### Constraining Execution

- ``workingDirectory(_:)``
- ``timeout(_:)-(Duration)``
- ``outputLimit(_:)``

### Providing Input

- ``stdin(_:)``

### Redirecting Output

- ``stdout(_:)``
- ``stderr(_:)``

### Running

- ``run(in:)``
- ``spawn(in:teardown:)``
- ``spawn(captureOutput:in:teardown:)``
- ``spawnRetainsOutput``

### Piping

- ``pipe(to:)``

### Inspecting

- ``executableName``
- ``arguments``
- ``executableOverride``
- ``environmentOverrides``
- ``unsetEnvironmentVariables``
- ``workingDirectoryOverride``
- ``timeoutOverride``
- ``outputLimitOverride``
- ``stdinSource``
- ``stdoutDestination``
- ``stderrDestination``
- ``displayString(using:)``
