# ``Mkdir``

A fluent wrapper for creating directories with `mkdir`.

Use ``parents(_:)`` for nested directory creation and ``mode(_:)-(FileMode)``
when a directory should be created with explicit POSIX permissions.

This creates `/tmp/swiftyshell/logs`, creating missing parent directories as
needed. The typed ``FileMode`` makes the intended permissions readable at the
call site: owner can read, write, and execute; group and others can read and
execute.

```swift
try await Mkdir(context: context)
    .parents()
    .mode(FileMode(owner: [.read, .write, .execute], group: [.read, .execute], other: [.read, .execute]))
    .directory("/tmp/swiftyshell/logs")
    .run()
```

## Topics

### Directory Options

- ``parents(_:)``
- ``mode(_:)-(FileMode)``
- ``mode(_:)-(String)``

### Paths

- ``directory(_:)``
- ``directories(_:)``

### Running

- ``init(context:)``
- ``command()``

### Related Types

- ``FileMode``
