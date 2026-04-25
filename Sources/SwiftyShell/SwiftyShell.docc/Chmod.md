# ``Chmod``

A fluent wrapper for changing permissions with `chmod`.

Prefer ``mode(_:)-(FileMode)`` for readable typed permission construction, or
use ``mode(_:)-(String)`` when you already have a shell-ready mode string.

```swift
try await Chmod(context: context)
    .recursive()
    .mode(FileMode(owner: [.read, .write, .execute], group: [.read, .execute], other: [.read, .execute]))
    .path("/tmp/swiftyshell")
    .run()

try await Chmod(context: context)
    .mode("644")
    .paths(["README.md", "LICENSE"])
    .run()
```

## Topics

### Permission Options

- ``recursive(_:)``
- ``mode(_:)-(FileMode)``
- ``mode(_:)-(String)``

### Paths

- ``path(_:)``
- ``paths(_:)``

### Running

- ``init(context:)``
- ``command()``

### Related Types

- ``FileMode``
