# ``Node``

A fluent wrapper for the Node.js runtime CLI (`node`).

``Node`` focuses on scripting entry points: version checks, inline JavaScript,
syntax checks, preload modules, and running script files with arguments.

Evaluate inline JavaScript:

```swift
let output = try await Node(context: context)
    .eval("console.log(process.version)")
    .run()
```

Run a script with runtime options and script arguments:

```swift
try await Node(context: context)
    .require("dotenv/config")
    .script("server.js")
    .scriptArguments(["--port", "3000"])
    .run()
```

## Topics

### Entry Points

- ``version()``
- ``eval(_:)``
- ``printExpression(_:)``
- ``check(_:)``
- ``script(_:)``

### Runtime Options

- ``require(_:)``
- ``inspect(_:)``
- ``watch(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``scriptArgument(_:)``
- ``scriptArguments(_:)``

### Running

- ``init(context:)``
- ``command()``
