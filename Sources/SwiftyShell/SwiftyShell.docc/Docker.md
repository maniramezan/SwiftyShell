# ``Docker``

A fluent wrapper for the Docker CLI (`docker`).

``Docker`` covers automation-friendly Docker workflows: Buildx, Compose, container and image
management, Docker Debug, Docker MCP, Docker Scout, and project initialization. It models common
global flags and high-value options while preserving raw escape hatches for subcommand-specific
arguments.

Build and push a multi-platform image with Buildx:

```swift
try await Docker(context: context)
    .buildx("build")
    .platform("linux/amd64,linux/arm64")
    .file("Dockerfile")
    .tag("owner/app:latest")
    .progress(.plain)
    .push()
    .positionalArgument(".")
    .run()
```

Run a non-interactive one-off container:

```swift
try await Docker(context: context)
    .subcommand("run")
    .removeWhenDone()
    .positionalArguments(["swift:6.1", "swift", "--version"])
    .run()
```

> Note: ``interactive(_:)`` and ``tty(_:)`` only add Docker CLI flags. SwiftyShell's `run()` does not provide terminal-backed stdin, so use them only with an external execution environment that supplies the required terminal behavior.

Use Docker Debug or MCP commands without needing dedicated types for each nested command:

```swift
try await Docker(context: context)
    .debug("nginx")
    .commandString("cat /etc/os-release")
    .run()

try await Docker(context: context)
    .mcp("server")
    .argument("list")
    .run()
```

Use ``argument(_:)``, ``arguments(_:)``, or ``option(_:_:)`` for command-specific flags that are not modeled.

## Topics

### Subcommands

- ``DockerSubcommand``
- ``subcommand(_:)-(DockerSubcommand)``
- ``subcommand(_:)-(String)``
- ``subcommand(_:_:)-(DockerSubcommand,String)``
- ``subcommand(_:_:)-(String,String)``
- ``buildx(_:)``
- ``compose(_:)``
- ``container(_:)``
- ``image(_:)``
- ``initialize()``
- ``debug(_:)``
- ``mcp(_:)``
- ``scout(_:)``
- ``system(_:)``
- ``version()``

### Global Options

- ``configPath(_:)``
- ``context(_:)``
- ``host(_:)``
- ``logLevel(_:)``
- ``debugMode(_:)``
- ``tls(_:)``
- ``tlsVerify(_:)``

### Build And Run Options

- ``DockerBuildProgress``
- ``platform(_:)``
- ``file(_:)``
- ``tag(_:)``
- ``tags(_:)``
- ``buildArg(_:)``
- ``buildArgs(_:)``
- ``progress(_:)``
- ``push(_:)``
- ``load(_:)``
- ``pull(_:)``
- ``name(_:)``
- ``removeWhenDone(_:)``
- ``detach(_:)``
- ``interactive(_:)``
- ``tty(_:)``
- ``commandString(_:)``
- ``shell(_:)``
- ``format(_:)``

### Raw Arguments

- ``option(_:)``
- ``option(_:_:)``
- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``

### Running

- ``init(context:)``
- ``command()``
