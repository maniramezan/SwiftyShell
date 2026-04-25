# ``Pwd``

A fluent wrapper for printing the current working directory with `pwd`.

``Pwd`` returns the selected directory path in ``ShellOutput/stdout``. Use
``physical(_:)`` when symlinks should be resolved and ``logical(_:)`` when the
shell's logical path should be preserved.

Resolve symlinks to get the physical directory path:

```swift
let physicalPath = try await Pwd(context: context)
    .physical()
    .run()
```

Preserve the logical path when your process entered the directory through a
symlink:

```swift
let logicalPath = try await Pwd(context: context)
    .logical()
    .run()
```

## Topics

### Path Resolution

- ``physical(_:)``
- ``logical(_:)``

### Running

- ``init(context:)``
- ``command()``
