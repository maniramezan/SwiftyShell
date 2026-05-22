# ``Terraform``

A fluent wrapper for the Terraform CLI.

``Terraform`` models high-value infrastructure automation commands such as
`init`, `plan`, `apply`, `destroy`, `validate`, `fmt`, `output`, and workspace
operations. It preserves raw flags for provider- or workflow-specific options.

Create a plan file in CI:

```swift
try await Terraform(context: context)
    .chdir("infra")
    .plan()
    .input(false)
    .noColor()
    .var("region=us-central1")
    .out("tfplan")
    .run()
```

Apply a saved plan:

```swift
try await Terraform(context: context)
    .apply()
    .autoApprove()
    .positionalArgument("tfplan")
    .run()
```

## Topics

### Subcommands

- ``TerraformSubcommand``
- ``subcommand(_:)-(TerraformSubcommand)``
- ``subcommand(_:)-(String)``
- ``initCommand()``
- ``plan()``
- ``apply()``
- ``destroy()``
- ``validate()``
- ``format()``
- ``output()``
- ``workspace(_:)``

### Options

- ``chdir(_:)``
- ``input(_:)``
- ``noColor(_:)``
- ``json(_:)``
- ``autoApprove(_:)``
- ``refresh(_:)``
- ``var(_:)-(String)``
- ``var(_:_:)``
- ``varFile(_:)``
- ``out(_:)``
- ``target(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``

### Running

- ``init(context:)``
- ``command()``
