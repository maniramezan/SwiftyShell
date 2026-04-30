# SwiftyShell

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmaniramezan%2FSwiftyShell%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/maniramezan/SwiftyShell)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmaniramezan%2FSwiftyShell%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/maniramezan/SwiftyShell)
[![CI](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftyShell/build.yml?branch=main&label=CI&logo=github)](https://github.com/maniramezan/SwiftyShell/actions/workflows/build.yml)
[![DocC](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftyShell/docc.yml?branch=main&label=DocC&logo=swift&logoColor=white)](https://github.com/maniramezan/SwiftyShell/actions/workflows/docc.yml)

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
let output = try await Command("my-tool", arguments: "--flag").run(in: context)
```

## Why Type-Safe?

- **No string composition.** Executables, arguments, env values, and output destinations are separate typed values — never concatenated strings that shell can reinterpret.
- **Structured results where they matter.** `Git` returns `GitStatus`; `ShellError` has named cases. No grepping stderr to decide what failed.
- **Workflow gates.** `require(_:equals:)` makes conditional chains — like "only pull if clean" — first-class, testable primitives.
- **Test without spawning processes.** Swap the executor for `MockExecutor` and every typed call becomes observable in unit tests.
- **`Command` is still there.** When you need something SwiftyShell hasn't modelled yet, `Command("tool", arguments: "arg").run(in: context)` is the same fluent API — no separate lower-level world.

## Installation

SwiftyShell uses [SwiftPM Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md) so you only compile the command families you actually use. The default trait set is **empty** — `Command`, `Pipeline`, `Workflow`, and `ShellContext` are always available, and you opt in to typed wrappers like `Git`, `Brew`, or `Ls` per consumer.

Add SwiftyShell to your `Package.swift` and select the families you need:

```swift
dependencies: [
    .package(
        url: "https://github.com/maniramezan/SwiftyShell.git",
        from: "0.1.0",
        traits: ["Git", "Grep"]   // pick only what you need
    )
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

Two umbrella traits cover common cases:

- `CommonUtilities` — enables every `Common/*` family (`Ls`, `Cp`, `Mkdir`, `Chmod`, `Rm`, `Mv`, `Pwd`, `Jq`).
- `All` — enables every command family SwiftyShell ships.

```swift
.package(url: "...", from: "0.1.0", traits: ["All"])
```

See the [Selecting Command Families](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/selectingcommandfamilies) guide for the full trait list and recipes.

## Built-in Command Families

SwiftyShell ships typed wrappers for common tools. Each family is gated behind a trait of the same name — opt in via the `traits:` parameter on `.package(...)` (see [Installation](#installation)). For full API reference, examples, and guides, see the [documentation](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/).

| Wrapper | Tool | Trait | Notes |
|---|---|---|---|
| `Git` | `git` | `Git` | Structured `GitStatus`, workflow gates, concurrent fetch |
| `Grep` | `grep` | `Grep` | Literal and regex patterns, recursive, case-insensitive |
| `Brew` | `brew` | `Brew` | Full top-level subcommand coverage, plus `--cask` and `--greedy` |
| `Ls` | `ls` | `Ls` | All flags, recursive, human-readable sizes |
| `Cp` | `cp` | `Cp` | Recursive, force |
| `Mkdir` | `mkdir` | `Mkdir` | Parent directories, permissions |
| `Chmod` | `chmod` | `Chmod` | Recursive permission updates |
| `Rm` | `rm` | `Rm` | Recursive, force |
| `Mv` | `mv` | `Mv` | Force |
| `Pwd` | `pwd` | `Pwd` | Physical and logical paths |
| `Jq` | `jq` | `Jq` | Filter expressions, `--arg` bindings, raw output |

When the tool you need isn't listed, `Command("tool", arguments: "arg").run(in: context)` is the fluent escape hatch. If you use the same tool repeatedly, promoting it to a typed family is straightforward — see below.

## Generate Your Own Typed Commands with AI

SwiftyShell ships an agent skill at `.claude/skills/swiftyshell.md` that teaches Claude (and compatible AI tools) the full API, coding conventions, and documentation requirements. Load it and describe the tool you want wrapped in plain English:

> "Add a typed wrapper for `rsync` with `--delete`, `--archive`, source and destination paths, and a dry-run flag."

The assistant will produce a complete `struct` conforming to `RunnableCommandFamily` — with a private `State`, fluent builder methods, a `command()` implementation that assembles `argv`, doc comments on every `public` declaration, and a unit test suite — ready to drop into `Sources/SwiftyShell/`.

The skill is automatically active when you open this repo in Claude Code. See the [Using AI Assistants](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/usingaiassistants) guide in the documentation for prompt tips and examples.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style guidelines, and pull request requirements. In short: every change must pass `swift test` **and** `swift-format lint --strict` before it is considered done.

## Changelog

Release notes live in [CHANGELOG.md](CHANGELOG.md).

## License

SwiftyShell is available under the MIT license. See [LICENSE](LICENSE) for details.
