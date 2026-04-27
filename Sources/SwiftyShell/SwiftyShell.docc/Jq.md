# ``Jq``

A fluent wrapper for transforming JSON with `jq`.

Use ``Jq`` for file-backed JSON extraction, generated JSON via ``nullInput(_:)``,
or variable-driven filters through ``arg(_:_:)``.

``Jq`` returns the transformed JSON or text in ``ShellOutput/stdout``. Use
``rawOutput(_:)`` when the result should be plain text instead of JSON-encoded
strings.

This reads `package.json` and returns the `.name` field as raw text:

```swift
let name = try await Jq(".name", context: context)
    .rawOutput()
    .file("package.json")
    .run()
```

Pass Swift values into filters with ``arg(_:_:)`` instead of interpolating them
into the jq program string:

```swift
let selected = try await Jq(".items[] | select(.id == $id)", context: context)
    .arg("id", "abc123")
    .file("data.json")
    .run()
```

Use ``nullInput(_:)`` when the filter generates JSON without reading an input
file:

```swift
let generated = try await Jq("{ok: true}", context: context)
    .nullInput()
    .compactOutput()
    .run()
```

## Topics

### Creating a Filter

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
