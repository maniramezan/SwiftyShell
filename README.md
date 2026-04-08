# SwiftyShell

Type-safe shell support for Swift. SwiftyShell lets you compose commands, pipelines, and typed workflows as Swift values — no raw shell strings required.

```swift
import SwiftyShell

let output = try await Command("ls", "-la")
    .pipe(to: Grep(".swift").command())
    .run(in: context)
```

## Requirements

- macOS 15.0+
- Swift 6.1+

## Installation

Add SwiftyShell to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftyShell", from: "0.1.0")
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

## Quick Start

### Shell Context

`ShellContext` holds execution defaults — executor, search paths, environment, working directory, timeout, and output limit. Create one and pass it to commands:

```swift
let context = ShellContext()

// Custom working directory and timeout
let context = ShellContext(
    workingDirectory: "/path/to/project",
    defaultTimeout: 30
)
```

### Simple Commands

```swift
let output = try await Command("pwd").run(in: context)
print(output.stdout)  // "/path/to/project\n"

// Builder-style argument composition
let output = try await Command("mkdir")
    .arg("-p")
    .arg("build/artifacts")
    .run(in: context)

// Environment override
try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .run(in: context)
```

### Pipelines

```swift
let output = try await Command("ls", "-la")
    .pipe(to: Grep(".swift").command())
    .run(in: context)

// Three-stage pipeline
let output = try await Command("cat", logPath)
    .pipe(to: Grep("ERROR").command())
    .pipe(to: Command("wc", "-l"))
    .run(in: context)
```

### Redirecting Output

```swift
// Discard output
try await Command("xcodebuild", "-scheme", "MyApp")
    .stdout(.discard)
    .run(in: context)

// Write to file (truncate)
try await Command("xcodebuild")
    .stdout(.file(path: "build.log", append: false))
    .run(in: context)

// Append to file
try await Command("xcodebuild", "-scheme", "Tests")
    .stdout(.file(path: "build.log", append: true))
    .run(in: context)
```

### Git Workflows

`Git` provides typed operations with structured results:

```swift
let git = Git(context: context)

// Check status
let status = try await git
    .workingDirectory(repoPath)
    .status()
    .run()

print(status.hasStagedChanges)   // Bool
print(status.branch)              // Optional<String>

// Require clean state before pulling
try await git
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Closure-based condition
try await git
    .workingDirectory(repoPath)
    .status()
    .require({ !$0.hasUnstagedChanges }, else: MyError.dirtyWorkingTree)
    .fetch()
    .run()
```

### Concurrent Execution

Commands and workflows are `Sendable` — use standard Swift concurrency:

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

### Grep

```swift
// Literal match (default)
let output = try await Grep("TODO")
    .file("Sources/MyApp/Feature.swift")
    .lineNumbers()
    .run()

// Regex match
let output = try await Grep.regex(#"func \w+\(.*\) async"#)
    .file("Sources/")
    .run()
```

### Timeouts and Cancellation

```swift
// Per-command timeout (seconds)
try await Command("curl", apiURL)
    .timeout(10)
    .run(in: context)

// Context-level default
let context = ShellContext(defaultTimeout: 60)

// Cancellation — standard Swift task cancellation propagates automatically
let task = Task {
    try await Command("long-running-tool").run(in: context)
}
task.cancel()  // sends SIGTERM then SIGKILL; throws ShellError.cancelled
```

### Error Handling

```swift
do {
    try await Command("git", "push").run(in: context)
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
| `cancelled` | Parent Swift task was cancelled |
| `workflowConditionFailed` | A `require` predicate returned false |
| `spawnError` | Process could not be spawned |

### Testing with MockExecutor

Inject `MockExecutor` to unit-test code that calls SwiftyShell without spawning real processes:

```swift
import SwiftyShell

// Fixed response
let context = ShellContext(executor: MockExecutor(stdout: "main\n"))

// Custom handler — inspect calls
var calls: [Command] = []
let context = ShellContext(executor: MockExecutor { command, _ in
    calls.append(command)
    return ShellOutput(stdout: "ok\n", stderr: "", exitCode: 0)
})

// Simulate failure
let context = ShellContext(executor: MockExecutor(exitCode: 1))
```

## Repository Layout

### `Sources/SwiftyShell/Core/`
Execution primitives: `Command`, `Pipeline`, `ShellContext`, `Workflow`, `ShellError`, `ShellOutput`, `OutputDestination`, `CommandExecutor`, `MockExecutor`, and the command-family protocol hierarchy.

### `Sources/SwiftyShell/Git/`
Typed git client returning structured results: `Git`, `GitStatus`, `GitStatusWorkflow`, `GitPullResult`, `GitFetchResult`.

### `Sources/SwiftyShell/Grep/`
Typed `grep` wrapper: `Grep` and `GrepPattern`.

### `Sources/SwiftyShell/Common/`
Typed wrappers for common shell utilities: `Ls`, `Cp`, `Mkdir`, `Rm`, `Mv`, `Pwd`, `Jq`.

### `Example/`
A standalone SwiftPM executable demonstrating real-world SwiftyShell usage. See the [`Example/`](Example/) directory for scripts covering automation, multi-repo tooling, and CI helpers.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style guidelines, and pull request requirements.

## License

SwiftyShell is available under the MIT license. See [LICENSE](LICENSE) for details.
