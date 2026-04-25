# ``Pwd``

A fluent wrapper for printing the current working directory with `pwd`.

```swift
let physicalPath = try await Pwd(context: context)
    .physical()
    .run()

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
