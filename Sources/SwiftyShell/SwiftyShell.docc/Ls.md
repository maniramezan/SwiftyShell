# ``Ls``

A fluent wrapper for listing directory contents with `ls`.

``Ls`` returns raw ``ShellOutput``. Use `stdout` when your tool needs to display
or parse the listing.

This maps to `ls -alh /tmp`, so hidden files are included, metadata is shown in
long format, and sizes are human-readable:

```swift
let listing = try await Ls(context: context)
    .all()
    .longFormat()
    .humanReadable()
    .path("/tmp")
    .run()
```

Use ``recursive(_:)`` to list descendants under a directory:

```swift
let recursiveListing = try await Ls(context: context)
    .recursive()
    .path("Sources")
    .run()
```

## Topics

### Listing Options

- ``all(_:)``
- ``longFormat(_:)``
- ``humanReadable(_:)``
- ``recursive(_:)``
- ``directoryAsFile(_:)``

### Paths

- ``path(_:)``
- ``paths(_:)``

### Running

- ``init(context:)``
- ``command()``
