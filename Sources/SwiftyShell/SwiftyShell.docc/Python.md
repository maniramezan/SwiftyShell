# ``Python``

A fluent wrapper for the Python interpreter CLI (`python3` by default).

``Python`` is for process-based script orchestration. It does not embed Python
or expose dynamic Python objects; use it when Swift automation needs to run
Python modules, inline commands, or script files as subprocesses.

Start a local HTTP server module:

```swift
try await Python(context: context)
    .module("http.server")
    .argument("8080")
    .run()
```

Run inline Python:

```swift
let output = try await Python(context: context)
    .commandString("print('hello')")
    .run()
```

## Topics

### Entry Points

- ``version()``
- ``module(_:)``
- ``commandString(_:)``
- ``script(_:)``

### Interpreter Options

- ``isolated(_:)``
- ``unbuffered(_:)``
- ``dontWriteBytecode(_:)``
- ``optimize(_:)``
- ``option(_:)``
- ``options(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``

### Running

- ``init(context:)``
- ``command()``
