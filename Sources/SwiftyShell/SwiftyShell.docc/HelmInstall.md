# ``HelmInstall``

Install a Helm chart as a named release.

## Overview

Cluster selection configured on ``Helm`` is carried into the install operation.

```swift
try await Helm()
    .namespace("production")
    .install(release: "api", chart: "./chart")
    .createNamespace()
    .valuesFile("values.production.yaml")
    .wait()
    .run()
```

## Topics

### Installation

- ``Helm/install(release:chart:)``
- ``HelmDryRunMode``
- ``HelmOutputFormat``
