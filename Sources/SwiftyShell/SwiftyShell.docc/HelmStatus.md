# ``HelmStatus``

Display the status of a named Helm release.

## Overview

Select a specific revision and request machine-readable output when needed.

```swift
let output = try await Helm()
    .namespace("production")
    .status(release: "api")
    .revision(3)
    .output(.yaml)
    .run()
```

## Topics

### Status

- ``Helm/status(release:)``
- ``HelmOutputFormat``
