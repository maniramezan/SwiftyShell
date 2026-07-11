# ``HelmUninstall``

Remove one or more Helm releases.

## Overview

Use `ignoreNotFound()` for idempotent cleanup automation.

```swift
try await Helm()
    .namespace("staging")
    .uninstall("api", "worker")
    .ignoreNotFound()
    .wait()
    .run()
```

## Topics

### Removal

- ``Helm/uninstall(_:)``
