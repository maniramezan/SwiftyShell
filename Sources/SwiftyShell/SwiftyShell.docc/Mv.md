# ``Mv``

A fluent wrapper for moving or renaming files and directories with `mv`.

``Mv`` returns ``ShellOutput`` for consistency, but a successful move usually has
no output. Use one source to rename or relocate a path, and multiple sources when
the destination is an existing directory.

This moves one log file into `/var/logs`:

```swift
try await Mv(context: context)
    .source("/tmp/output.log")
    .destination("/var/logs/output.log")
    .run()
```

This moves multiple build artifacts into an archive directory and overwrites
conflicting destination files when the platform `mv` supports it:

```swift
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
