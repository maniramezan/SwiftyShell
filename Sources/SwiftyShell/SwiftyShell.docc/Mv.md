# ``Mv``

A fluent wrapper for moving or renaming files and directories with `mv`.

```swift
try await Mv(context: context)
    .source("/tmp/output.log")
    .destination("/var/logs/output.log")
    .run()

try await Mv(context: context)
    .force()
    .sources(["build/app", "build/app.dSYM"])
    .destination("/tmp/archive")
    .run()
```

## Topics

### Move Options

- ``force(_:)``

### Sources And Destination

- ``source(_:)``
- ``sources(_:)``
- ``destination(_:)``

### Running

- ``init(context:)``
- ``command()``
