# ``Helm``

Build operation-specific Helm commands without exposing invalid cross-command flags.

## Overview

``Helm`` stores shared execution and cluster selection configuration. Its factory methods return
distinct command values for template rendering, chart linting, installation, upgrade,
uninstallation, release listing, and release status.

```swift
let output = try await Helm()
    .namespace("production")
    .kubeContext("prod-cluster")
    .upgrade(release: "api", chart: "./charts/api")
    .installIfMissing()
    .valuesFiles(["values.yaml", "values.production.yaml"])
    .set("image.tag", to: "1.4.0")
    .wait()
    .output(.json)
    .run()
```

Values files and `--set` variants remain in call order, matching Helm's right-most override
precedence. Output format is available only on operations supported by Helm. Use
``OutputRedirectingCommandFamily/stdout(_:)`` when you need process-level stream redirection
instead of Helm's `--output` format.

Render and inspect one template locally:

```swift
let rendered = try await Helm()
    .template(name: "api", chart: "./charts/api")
    .valuesFile("values.test.yaml")
    .showOnly("templates/deployment.yaml")
    .run()
```

## Topics

### Operations

- ``HelmTemplate``
- ``HelmLint``
- ``HelmInstall``
- ``HelmUpgrade``
- ``HelmUninstall``
- ``HelmList``
- ``HelmStatus``

### Options

- ``HelmOutputFormat``
- ``HelmDryRunMode``
- ``HelmReleaseStatus``
