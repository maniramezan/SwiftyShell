# ``Ls``

A fluent wrapper for listing directory contents with `ls`.

```swift
let listing = try await Ls(context: context)
    .all()
    .longFormat()
    .humanReadable()
    .path("/tmp")
    .run()

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
