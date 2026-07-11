# ``HelmList``

List Helm releases with operation-specific filters and output formats.

## Overview

Status filters can be combined to select multiple release states.

```swift
let output = try await Helm()
    .list()
    .allNamespaces()
    .status(.deployed)
    .status(.failed)
    .output(.json)
    .run()
```

## Topics

### Listing

- ``Helm/list()``
- ``HelmReleaseStatus``
- ``HelmOutputFormat``
