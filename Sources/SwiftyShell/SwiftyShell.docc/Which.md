# ``Which``

Locate an executable without treating normal absence as an error.

Use ``Which/lookup()`` to receive ``WhichResult/found(path:)`` or
``WhichResult/notFound``. The workflow maps the conventional `which` exit status `1` to
not-found while preserving other process failures as ``ShellError`` values.

```swift
switch try await Which("swift", context: context).lookup().run() {
case .found(let path):
    print(path)
case .notFound:
    print("Swift is unavailable")
}
```

## Topics

### Lookup

- ``init(_:context:)``
- ``lookup()``
- ``command()``
- ``WhichResult``
