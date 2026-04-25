# ``Cp``

A fluent wrapper for copying files and directories with `cp`.

``Cp`` returns ``ShellOutput`` for consistency with other command families, but a
successful copy usually has empty `stdout` and `stderr`. Treat successful
completion as the result.

Copy one file by providing a source and destination:

```swift
try await Cp(context: context)
    .source("Config/defaults.json")
    .destination("/tmp/defaults.json")
    .run()
```

Use ``recursive(_:)`` for directories and ``force(_:)`` when an existing
destination should be overwritten:

```swift
try await Cp(context: context)
    .recursive()
    .force()
    .source("Assets")
    .destination("/tmp/Assets")
    .run()
```

## Topics

### Copy Options

- ``recursive(_:)``
- ``force(_:)``

### Sources And Destination

- ``source(_:)``
- ``sources(_:)``
- ``destination(_:)``

### Running

- ``init(context:)``
- ``command()``
