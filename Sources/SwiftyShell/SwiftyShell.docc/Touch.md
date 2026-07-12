# ``Touch``

Create files or update their access and modification timestamps.

The initializer requires the first path, while ``path(_:)`` and ``paths(_:)`` append more.
Portable timestamp selection is available through a reference file or the standard
`[[CC]YY]MMDDhhmm[.SS]` representation.

```swift
try await Touch("build.stamp")
    .modificationTimeOnly()
    .run()
```

```swift
try await Touch("output")
    .reference("input")
    .noCreate()
    .run()
```

## Topics

### Timestamps

- ``init(_:context:)``
- ``accessTimeOnly(_:)``
- ``modificationTimeOnly(_:)``
- ``noCreate(_:)``
- ``reference(_:)``
- ``timestamp(_:)``
- ``path(_:)``
- ``paths(_:)``
- ``command()``
