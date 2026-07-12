# ``Kubectl``

A fluent wrapper for the Kubernetes `kubectl` CLI.

``Kubectl`` covers common cluster automation: reading resources, applying files,
deleting resources, fetching logs, executing container commands, and shared
selection flags like kubeconfig, context, namespace, output, selectors, and
containers.

List pods as JSON:

```swift
let pods = try await Kubectl(context: context)
    .get("pods")
    .namespace("default")
    .output("json")
    .run()
```

Apply a manifest:

```swift
try await Kubectl(context: context)
    .apply()
    .filename("deploy.yml")
    .run()
```

Execute a command in a container. ``exec(_:command:)`` places `--` after the pod and kubectl
options automatically, so command flags are forwarded safely:

```swift
try await Kubectl(context: context)
    .exec("pod/api", command: ["env", "--show-hidden"])
    .container("api")
    .run()
```

## Topics

### Subcommands

- ``KubectlSubcommand``
- ``subcommand(_:)-(KubectlSubcommand)``
- ``subcommand(_:)-(String)``
- ``get(_:)``
- ``describe(_:)``
- ``apply()``
- ``delete(_:)``
- ``logs(_:)``
- ``exec(_:command:)``

### Options

- ``kubeconfig(_:)``
- ``contextName(_:)``
- ``namespace(_:)``
- ``output(_:)``
- ``filename(_:)``
- ``selector(_:)``
- ``container(_:)``
- ``allNamespaces(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``

### Running

- ``init(context:)``
- ``command()``
