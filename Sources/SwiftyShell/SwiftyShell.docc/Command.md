# ``Command``

A value describing a single shell command and its execution overrides.

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
- ``env(_:)-4bj2``

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
