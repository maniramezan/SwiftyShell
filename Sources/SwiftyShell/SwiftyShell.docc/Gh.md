# ``Gh``

A fluent wrapper for the GitHub CLI (`gh`).

``Gh`` covers automation-friendly GitHub CLI workflows: pull requests, issues, repositories,
workflow runs, releases, API calls, extensions, Copilot, skills, SSH keys, and agent tasks. It
models the command group and common global flags while preserving escape hatches for subcommand
specific options.

View a pull request as JSON:

```swift
try await Gh(context: context)
    .pr("view")
    .repo("owner/project")
    .json(["number", "title", "state"])
    .run()
```

Create an agent task:

```swift
try await Gh(context: context)
    .agentTask("create")
    .positionalArgument("Improve the release automation")
    .run()
```

Call the GitHub API with command-specific raw options:

```swift
try await Gh(context: context)
    .api("repos/owner/project/issues")
    .option("--method", "POST")
    .option("--field")
    .argument("title=Bug")
    .run()
```

Use ``argument(_:)``, ``arguments(_:)``, or ``option(_:_:)`` for command-specific flags that are not modeled.

## Topics

### Subcommands

- ``GhSubcommand``
- ``subcommand(_:)-(GhSubcommand)``
- ``subcommand(_:)-(String)``
- ``subcommand(_:_:)-(GhSubcommand,String)``
- ``subcommand(_:_:)-(String,String)``
- ``version()``
- ``agentTask(_:)``
- ``agent(_:)``
- ``agents(_:)``
- ``agentTasks(_:)``
- ``alias(_:)``
- ``api(_:)``
- ``attestation(_:)``
- ``auth(_:)``
- ``browse(_:)``
- ``cache(_:)``
- ``completion(_:)``
- ``config(_:)``
- ``copilot()``
- ``extensionCommand(_:)``
- ``gist(_:)``
- ``gpgKey(_:)``
- ``issue(_:)``
- ``label(_:)``
- ``licenses()``
- ``org(_:)``
- ``pr(_:)``
- ``project(_:)``
- ``release(_:)``
- ``repoCommand(_:)``
- ``ruleset(_:)``
- ``runCommand(_:)``
- ``search(_:)``
- ``secret(_:)``
- ``skill(_:)``
- ``sshKey(_:)``
- ``status()``
- ``variable(_:)``
- ``workflow(_:)``

### Common Options

- ``repo(_:)``
- ``hostname(_:)``
- ``json(_:)-([String])``
- ``json(_:)-(String...)``
- ``jq(_:)``
- ``template(_:)``
- ``limit(_:)``
- ``web(_:)``
- ``confirm(_:)``
- ``silent(_:)``

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
