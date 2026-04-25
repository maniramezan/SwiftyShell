# ``Rm``

A fluent wrapper for removing files and directories with `rm`.

Successful removals usually produce no output, so completion is the important
result. Failures throw ``ShellError/exitFailure(command:output:)`` with the tool's
diagnostic text in `stderr`.

Remove a single file by passing its path:

```swift
try await Rm(context: context)
    .path("/tmp/output.log")
    .run()
```

Use ``recursive(_:)`` for directories and ``force(_:)`` when missing paths should
not fail the command:

```swift
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
