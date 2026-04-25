# ``Cp``

A fluent wrapper for copying files and directories with `cp`.

```swift
try await Cp(context: context)
    .source("Config/defaults.json")
    .destination("/tmp/defaults.json")
    .run()

try await Cp(context: context)
    .recursive()
    .force()
    .source("Assets")
    .destination("/tmp/Assets")
    .run()
```

## Topics

### Copy Options

- ``recursive(_:)``
- ``force(_:)``

### Sources And Destination

- ``source(_:)``
- ``sources(_:)``
- ``destination(_:)``

### Running

- ``init(context:)``
- ``command()``
