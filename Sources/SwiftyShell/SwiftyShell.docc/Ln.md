# ``Ln``

Create hard or symbolic links with required source and destination operands.

``Ln`` defaults to a hard link. Its typed options use the portable `ln -s` and `ln -f`
behavior shared by macOS and GNU systems.

```swift
try await Ln(source: "releases/1.2.0", destination: "current")
    .symbolic()
    .force()
    .run()
```

## Topics

### Creating Links

- ``init(source:destination:context:)``
- ``symbolic(_:)``
- ``force(_:)``
- ``command()``
