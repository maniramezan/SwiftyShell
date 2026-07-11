# ``HelmUpgrade``

Upgrade a Helm release, optionally installing it when absent.

## Overview

Values files and set overrides retain Helm's right-most precedence.

```swift
try await Helm()
    .upgrade(release: "api", chart: "./chart")
    .installIfMissing()
    .reuseValues()
    .set("image.tag", to: "1.4.0")
    .cleanupOnFailure()
    .run()
```

## Topics

### Upgrade

- ``Helm/upgrade(release:chart:)``
- ``HelmDryRunMode``
- ``HelmOutputFormat``
