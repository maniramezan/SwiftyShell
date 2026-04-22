# SwiftyShell

[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-F05138?logo=swift)](Package.swift)
[![Build and Test](https://github.com/maniramezan/SwiftyShell/actions/workflows/build.yml/badge.svg)](https://github.com/maniramezan/SwiftyShell/actions/workflows/build.yml)

**Type-safe shell support for Swift.** SwiftyShell models shell concepts — tools, subcommands, flags, pipelines, workflows — as Swift values. You pick a typed wrapper like `Git`, `Grep`, `Brew`, or `Ls` and the compiler enforces the shape of the call. When a tool does not yet have a typed wrapper, `Command` is the fluent escape hatch for arbitrary executables — but the typed APIs are the default.

```swift
import SwiftyShell

// Typed: the compiler knows what `Git` can do
let status = try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Typed: Brew as a value, not a raw shell string
try await Brew(context: context)
    .install("ripgrep", "fzf")
    .run()

// Escape hatch: run anything not yet modelled
let output = try await Command("my-tool", "--flag").run(in: context)
```

## Why Type-Safe?

- **No string composition.** Executables, arguments, env values, and output destinations are separate typed values — never concatenated strings that shell can reinterpret.
- **Structured results where they matter.** `Git` returns `GitStatus`; `ShellError` has named cases. No grepping stderr to decide what failed.
- **Workflow gates.** `require(_:equals:)` makes conditional "only pull if clean" chains a first-class, testable primitive.
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
    .package(url: "https://github.com/maniramezan/SwiftyShell.git", branch: "main")
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

Then `import SwiftyShell` in your Swift files.

Until the first tagged release is published, depend on `branch: "main"`. Switch to `from: "<tag>"` once a release tag exists.

## Shell Context

Every SwiftyShell call — typed or raw — runs in a `ShellContext`, which holds the executor, search paths, environment, working directory, default timeout, and default output limit.

```swift
let context = ShellContext()

// Custom working directory and timeout
let context = ShellContext(
    workingDirectory: "/path/to/project",
    defaultTimeout: 30
)
```

Pass the same context to typed families and to raw `Command`s — they share the same configuration surface.

## Typed Command Families

This is the primary API. Reach for `Command` only when the tool you need isn't modelled here yet.

### Git

`Git` returns structured results and supports conditional workflow gates:

```swift
let git = Git(context: context)

// Structured status
let status = try await git
    .workingDirectory(repoPath)
    .status()
    .run()

print(status.branch ?? "detached HEAD")
print(status.hasStagedChanges, status.hasUnstagedChanges)

// "Only pull if clean" as a typed gate
try await git
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Closure-based gate with a domain error
try await git
    .workingDirectory(repoPath)
    .status()
    .require({ !$0.hasUnstagedChanges }, else: MyError.dirtyWorkingTree)
    .fetch()
    .run()
```

### Grep

```swift
// Literal match (default)
let output = try await Grep("TODO", context: context)
    .file("Sources/MyApp/Feature.swift")
    .lineNumbers()
    .run()

// Regex match
let output = try await Grep.regex(#"func \w+\(.*\) async"#, context: context)
    .recursive()
    .file("Sources/")
    .run()
```

### Homebrew

`Brew` models `brew` subcommands as typed methods. Default subcommand is `list`, so `Brew(context: context).run()` safely lists installed formulae.

```swift
// Install formulae
try await Brew(context: context)
    .install("ripgrep", "fzf")
    .run()

// Install a cask
try await Brew(context: context)
    .install("firefox")
    .cask()
    .run()

// Outdated packages (greedy includes casks with auto-updates)
let outdated = try await Brew(context: context)
    .outdated()
    .greedy()
    .run()
print(outdated.stdout)
```

### File-System Utilities

Typed wrappers for common POSIX tools. Each exposes only the flags that exist on the underlying command:

```swift
try await Mkdir(context: context).parents().directory("/tmp/build").run()
try await Cp(context: context).recursive().source("build/").destination("/tmp/dist").run()
try await Mv(context: context).source("/tmp/out.log").destination("/var/log/out.log").run()
try await Rm(context: context).recursive().force().path("/tmp/old-build").run()

let listing = try await Ls(context: context).all().longFormat().path("/tmp").run()
let cwd = try await Pwd(context: context).physical().run()
```

### Jq

```swift
let name = try await Jq(".name", context: context)
    .rawOutput()
    .file("package.json")
    .run()
```

### Typed Pipelines

Typed families produce `Command` values via `.command()`, so you can pipe them without dropping out of the typed world:

```swift
// ls -la | grep .swift
let output = try await Command("ls", "-la")
    .pipe(to: Grep(".swift", context: context).command())
    .run(in: context)

// cat log | grep ERROR | wc -l
let output = try await Command("cat", logPath)
    .pipe(to: Grep("ERROR", context: context).command())
    .pipe(to: Command("wc", "-l"))
    .run(in: context)
```

### Concurrent Execution

Typed clients are `Sendable`, so they compose with Swift Concurrency:

```swift
// Two repos in parallel
let git = Git(context: context)
async let statusA = git.workingDirectory(repoA).status().run()
async let statusB = git.workingDirectory(repoB).status().run()
let (a, b) = try await (statusA, statusB)

// N repos with TaskGroup
try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
    for path in repoPaths {
        group.addTask {
            try await git.workingDirectory(path).fetch().run()
        }
    }
    for try await _ in group {}
}
```

## Raw `Command` — The Escape Hatch

When a tool isn't modelled as a typed family yet, drop down to `Command`. It uses the same fluent builder style as the typed APIs, so your code does not change shape:

```swift
// Anything on the search path
let output = try await Command("pwd").run(in: context)

// Arguments, environment, working directory, timeout
try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .workingDirectory("/var/app")
    .timeout(120)
    .run(in: context)

// Redirect stdout/stderr to a file
try await Command("xcodebuild", "-scheme", "MyApp")
    .stdout(.file(path: "build.log", append: false))
    .stderr(.file(path: "build.log", append: true))
    .run(in: context)
```

If you find yourself reaching for `Command` for the same tool repeatedly, it's probably a good candidate for a typed family — see [`CONTRIBUTING.md`](CONTRIBUTING.md#adding-a-new-typed-command-family).

## Timeouts and Cancellation

Both typed families and raw `Command`s share the same timeout and cancellation model:

```swift
// Per-command timeout (seconds)
try await Command("curl", apiURL)
    .timeout(10)
    .run(in: context)

// Per-client timeout
try await Git(context: context).timeout(30).fetch().run()

// Context-level default
let context = ShellContext(defaultTimeout: 60)

// Cancellation — standard Swift task cancellation propagates automatically
let task = Task {
    try await Command("long-running-tool").run(in: context)
}
task.cancel()  // sends SIGTERM then SIGKILL; throws ShellError.cancelled
```

## Error Handling

All failures surface as `ShellError`. Catch specific cases rather than parsing message strings:

```swift
do {
    try await Git(context: context).workingDirectory(repoPath).pull().run()
} catch ShellError.exitFailure(let command, let output) {
    print("'\(command)' failed: \(output.stderr)")
} catch ShellError.commandNotFound(let name) {
    print("'\(name)' not found — check ShellContext.searchPaths")
} catch ShellError.timeout(let command, let duration, _) {
    print("'\(command)' timed out after \(duration)s")
}
```

| Error case | Cause |
|---|---|
| `commandNotFound` | Executable not on search path |
| `exitFailure` | Non-zero exit code |
| `timeout` | Command exceeded time limit |
| `outputLimitExceeded` | Output exceeded configured limit |
| `decodingError` | Output is not valid UTF-8 |
| `invalidConfiguration` | Timeout or output limit was negative |
| `cancelled` | Parent Swift task was cancelled |
| `workflowConditionFailed` | A `require` predicate returned false |
| `spawnError` | Process could not be spawned |

## Testing with MockExecutor

Inject `MockExecutor` to unit-test code that calls SwiftyShell — typed families and raw `Command`s alike — without spawning real processes:

```swift
import SwiftyShell

// Fixed response — works for any typed family through the same context
let context = ShellContext(executor: MockExecutor(stdout: "## main...origin/main\n"))
let status = try await Git(context: context).status().run()
#expect(status.branch == "main")

// Custom handler — inspect calls
actor CallRecorder {
    var calls: [Command] = []
    func record(_ command: Command) { calls.append(command) }
}
let recorder = CallRecorder()
let context = ShellContext(executor: MockExecutor { command, _ in
    await recorder.record(command)
    return ShellOutput(stdout: "ok\n", stderr: "", exitCode: 0)
})

// Simulate failure. MockExecutor mirrors real run() semantics and throws exitFailure.
let context = ShellContext(executor: MockExecutor(exitCode: 1))
```

## Repository Layout

### `Sources/SwiftyShell/Core/`
Execution primitives: `Command`, `Pipeline`, `ShellContext`, `Workflow`, `ShellError`, `ShellOutput`, `OutputDestination`, `CommandExecutor`, `MockExecutor`, and the command-family protocol hierarchy.

### `Sources/SwiftyShell/Git/`
Typed git client returning structured results: `Git`, `GitStatus`, `GitWorkingTreeState`, `GitStatusWorkflow`, `GitPullResult`, `GitFetchResult`.

### `Sources/SwiftyShell/Grep/`
Typed `grep` wrapper: `Grep` and `GrepPattern`.

### `Sources/SwiftyShell/Brew/`
Typed Homebrew wrapper: `Brew` and `BrewSubcommand`.

### `Sources/SwiftyShell/Common/`
Typed wrappers for common shell utilities: `Ls`, `Cp`, `Mkdir`, `Rm`, `Mv`, `Pwd`, `Jq`.

### `Example/`
A standalone SwiftPM executable demonstrating real-world SwiftyShell usage. See the [`Example/`](Example/) directory for scripts covering automation, multi-repo tooling, and CI helpers.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style guidelines, and pull request requirements. In short: every change must pass `swift test` **and** `swift-format lint --strict` before it is considered done.

## License

SwiftyShell is available under the MIT license. See [LICENSE](LICENSE) for details.
