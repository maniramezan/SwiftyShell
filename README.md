# SwiftyShell

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![Build and Test](https://github.com/maniramezan/SwiftyShell/actions/workflows/build.yml/badge.svg)](https://github.com/maniramezan/SwiftyShell/actions/workflows/build.yml)

**Type-safe shell support for Swift.** SwiftyShell models shell concepts — tools, subcommands, flags, pipelines, workflows — as Swift values. You pick a typed wrapper like `Git`, `Grep`, `Brew`, or `Ls` and the compiler enforces the shape of the call. When a tool does not yet have a typed wrapper, `Command` is the fluent escape hatch for arbitrary executables — but the typed APIs are the default.

```swift
import SwiftyShell

let context = ShellContext()

// Typed: compiler-enforced git workflow with a clean-tree gate
try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Escape hatch: run anything not yet modelled
let output = try await Command("my-tool", "--flag").run(in: context)
```

## Why Type-Safe?

- **No string composition.** Executables, arguments, env values, and output destinations are separate typed values — never concatenated strings that shell can reinterpret.
- **Structured results where they matter.** `Git` returns `GitStatus`; `ShellError` has named cases. No grepping stderr to decide what failed.
- **Workflow gates.** `require(_:equals:)` makes conditional chains — like "only pull if clean" — first-class, testable primitives.
- **Test without spawning processes.** Swap the executor for `MockExecutor` and every typed call becomes observable in unit tests.
- **`Command` is still there.** When you need something SwiftyShell hasn't modelled yet, `Command("tool", "arg").run(in: context)` is the same fluent API — no separate lower-level world.

## Requirements

- macOS 15.0+
- Linux with Foundation `Process` support (validated in CI with Swift 6.1 on `swift:6.1` / Ubuntu)
- Swift 6.1+

## Installation

Add SwiftyShell to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftyShell.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SwiftyShell", package: "SwiftyShell")
        ]
    )
]
```

## Built-in Command Families

SwiftyShell ships typed wrappers for common tools. For full API reference, examples, and guides, see the [documentation](https://maniramezan.github.io/swiftyshell/documentation/swiftyshell/).

| Wrapper | Tool | Notes |
|---|---|---|
| `Git` | `git` | Structured `GitStatus`, workflow gates, concurrent fetch |
| `Grep` | `grep` | Literal and regex patterns, recursive, case-insensitive |
| `Brew` | `brew` | Full subcommand coverage including `--cask` and `--greedy` |
| `Ls` | `ls` | All flags, recursive, human-readable sizes |
| `Cp` | `cp` | Recursive, force |
| `Mkdir` | `mkdir` | Parent directories, permissions |
| `Rm` | `rm` | Recursive, force |
| `Mv` | `mv` | Force |
| `Pwd` | `pwd` | Physical and logical paths |
| `Jq` | `jq` | Filter expressions, `--arg` bindings, raw output |

When the tool you need isn't listed, `Command("tool", "arg").run(in: context)` is the fluent escape hatch. If you find yourself using the same tool repeatedly via `Command`, it is a good candidate for a typed family — see [Contributing](#contributing).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style guidelines, and pull request requirements. In short: every change must pass `swift test` **and** `swift-format lint --strict` before it is considered done.

## License

SwiftyShell is available under the MIT license. See [LICENSE](LICENSE) for details.
