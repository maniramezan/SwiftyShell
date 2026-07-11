# ``HelmLint``

Check a Helm chart for structural and convention issues.

## Overview

Use strict mode when warnings should fail automated validation.

```swift
try await Helm()
    .lint(chart: "./chart")
    .valuesFile("values.test.yaml")
    .strict()
    .withSubcharts()
    .run()
```

## Topics

### Validation

- ``Helm/lint(chart:)``
