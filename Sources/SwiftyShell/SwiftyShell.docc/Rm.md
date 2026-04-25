# ``Rm``

A fluent wrapper for removing files and directories with `rm`.

```swift
try await Rm(context: context)
    .path("/tmp/output.log")
    .run()

try await Rm(context: context)
    .recursive()
    .force()
    .path("/tmp/old-build")
    .run()
```

## Topics

### Removal Options

- ``recursive(_:)``
- ``force(_:)``

### Paths

- ``path(_:)``
- ``paths(_:)``

### Running

- ``init(context:)``
- ``command()``
