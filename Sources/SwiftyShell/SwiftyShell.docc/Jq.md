# ``Jq``

A fluent wrapper for transforming JSON with `jq`.

Use ``Jq`` for file-backed JSON extraction, generated JSON via ``nullInput(_:)``,
or variable-driven filters through ``arg(_:_:)``.

```swift
let name = try await Jq(".name", context: context)
    .rawOutput()
    .file("package.json")
    .run()

let selected = try await Jq(".items[] | select(.id == $id)", context: context)
    .arg("id", "abc123")
    .file("data.json")
    .run()

let generated = try await Jq("{ok: true}", context: context)
    .nullInput()
    .compactOutput()
    .run()
```

## Topics

### Creating A Filter

- ``init(_:context:)``
- ``filter(_:)``

### Output Options

- ``rawOutput(_:)``
- ``compactOutput(_:)``
- ``sortKeys(_:)``

### Input Options

- ``slurp(_:)``
- ``nullInput(_:)``
- ``arg(_:_:)``
- ``file(_:)``
- ``files(_:)``

### Running

- ``command()``

### Related Types

- ``JqArgument``
