# SwiftyShell

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmaniramezan%2FSwiftyShell%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/maniramezan/SwiftyShell)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmaniramezan%2FSwiftyShell%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/maniramezan/SwiftyShell)
[![CI](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftyShell/build.yml?branch=main&label=CI&logo=github)](https://github.com/maniramezan/SwiftyShell/actions/workflows/build.yml)
[![DocC](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftyShell/docc.yml?branch=main&label=DocC&logo=swift&logoColor=white)](https://github.com/maniramezan/SwiftyShell/actions/workflows/docc.yml)

**Swift-typed shell support.** SwiftyShell models commands, arguments, pipelines, and workflows as Swift values. Use typed wrappers for supported tools, or `Command` for any executable.

```swift
import SwiftyShell

let output = try await Command("echo", arguments: "hello").run()
print(output.stdout)
```

Typed command families are opt-in through SwiftPM package traits. The default package enables only the core execution API.

## Start here

- [Getting started](Guides/GETTING_STARTED.md) — add the package and run a command
- [Supported commands](Guides/SUPPORTED_COMMANDS.md) — wrappers, traits, and escape hatch
- [Execution behavior](Guides/EXECUTION.md) — pipelines, output, timeouts, and spawned processes
- [Development](Guides/DEVELOPMENT.md) — validation, Linux helpers, and contribution links
- [DocC documentation](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/) — tutorials, family guides, and full API reference

## Why SwiftyShell?

- Commands keep executable names, argv entries, environment, and output routing explicit.
- Typed wrappers provide discoverable options and structured results where available.
- `Workflow` composes asynchronous operations with gates such as “continue only if the working tree is clean.”
- `MockExecutor` lets you test command construction without launching processes.

SwiftyShell is not a security boundary. Validate values according to the invoked tool, especially interpreter input, raw options, executable overrides, environment values, and writable paths.

## License

SwiftyShell is available under the MIT license. See [LICENSE](LICENSE) for details.
