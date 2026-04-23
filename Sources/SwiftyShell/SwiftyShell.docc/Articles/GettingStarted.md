# Getting Started with SwiftyShell

Reach for a typed command family first; drop to a raw ``Command`` only when no typed wrapper exists yet.

## Overview

SwiftyShell's primary API is a family of typed wrappers (``Git``, ``Grep``, ``Brew``,
``Ls``, ``Cp``, ``Mkdir``, ``Chmod``, ``Rm``, ``Mv``, ``Pwd``, ``Jq``) that model shell tools
as Swift values. The compiler enforces which flags exist, which arguments are
required, and what the result looks like. ``Command`` is the fluent escape hatch
for anything not yet modelled — it shares the same builder style so code does
not change shape when you fall back to it.

## Installation

Add SwiftyShell to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftyShell.git", branch: "main"),
],
targets: [
    .target(
        name: "MyTool",
        dependencies: ["SwiftyShell"]
    ),
]
```

Until the first tagged release is published, depend on `branch: "main"`. Switch to `from: "<tag>"` after the first release tag is available.

## Shell Context

Every call — typed or raw — runs in a ``ShellContext`` that holds the executor,
search paths, environment, working directory, default timeout, and default
output limit:

```swift
import SwiftyShell

let context = ShellContext()

// Override defaults as needed
let scopedContext = ShellContext(
    workingDirectory: "/var/app",
    defaultTimeout: 30
)
```

Pass the same context to typed families and raw commands.

## Type-Safe Tools First

### Git

``Git`` returns structured results and exposes typed workflow gates:

```swift
let git = Git(context: context)

let status = try await git
    .workingDirectory("/path/to/repo")
    .status()
    .run()
print(status.branch ?? "detached HEAD", status.state)

// Only pull if the working tree is clean
try await git
    .workingDirectory("/path/to/repo")
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()
```

### Grep

```swift
let matches = try await Grep("TODO", context: context)
    .recursive()
    .lineNumbers()
    .file("Sources/")
    .run()

let asyncFuncs = try await Grep.regex(#"func \w+\(.*\) async"#, context: context)
    .file("Sources/")
    .run()
```

### Brew

``Brew`` models `brew` subcommands as typed methods. Default subcommand is
``BrewSubcommand/list``.

```swift
try await Brew(context: context).install("ripgrep", "fzf").run()

let outdated = try await Brew(context: context).outdated().greedy().run()
```

### File-System Utilities

```swift
try await Mkdir(context: context).parents().directory("/tmp/build").run()
try await Cp(context: context).recursive().source("build/").destination("/tmp/dist").run()
try await Mv(context: context).source("/tmp/out.log").destination("/var/log/out.log").run()
try await Rm(context: context).recursive().force().path("/tmp/old-build").run()
let listing = try await Ls(context: context).all().longFormat().path("/tmp").run()
```

When you need to provision a directory tree with explicit permissions, pair
``Mkdir`` with ``Chmod``:

```swift
try await Mkdir(context: context)
    .parents()
    .mode(
        FileMode(
            owner: [.read, .write, .execute],
            group: [.read, .execute],
            other: [.read, .execute]
        )
    )
    .directory("/tmp/output/logs")
    .run()

try await Chmod(context: context)
    .mode(
        FileMode(
            owner: [.read, .write, .execute],
            group: [.read, .execute],
            other: [.read, .execute]
        )
    )
    .path("/tmp/output/logs")
    .run()
```

### Pipelines of Typed Commands

Typed families hand out ``Command`` values via ``RunnableCommandFamily/command()``,
so you can pipe them without dropping out of the typed world:

```swift
// ls -la | grep .swift | wc -l
let output = try await Command("ls", "-la")
    .pipe(to: Grep(".swift", context: context).command())
    .pipe(to: Command("wc", "-l"))
    .run(in: context)
```

## Raw `Command` — The Escape Hatch

Use ``Command`` when the tool you need isn't modelled yet. It uses the same
fluent builder style, so your code does not change shape:

```swift
// Simple invocation
let output = try await Command("echo", "Hello, SwiftyShell!").run(in: context)

// Arguments, env, working directory, timeout
try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .workingDirectory("/var/app")
    .timeout(300)
    .run(in: context)

// Redirect stdout/stderr
try await Command("swift", "build", "--verbose")
    .stdout(.file(path: "/tmp/build.log", append: false))
    .stderr(.file(path: "/tmp/build.log", append: true))
    .run(in: context)
```

If you reach for ``Command`` repeatedly for the same tool, promoting it to a
typed family is a good investment — see <doc:BuildingCommandFamilies>.

## Reading Output

``ShellOutput`` captures stdout, stderr, and the exit code — for both typed
families and raw commands:

```swift
let output = try await Command("git", "log", "--oneline", "-5").run(in: context)

if output.isSuccess {
    for line in output.stdout.split(whereSeparator: \.isNewline) {
        print(line)
    }
} else {
    print("git failed:", output.stderr)
}
```

## Handling Errors

All failures surface as ``ShellError``. Catch specific cases rather than parsing message strings:

```swift
do {
    try await Git(context: context).workingDirectory(repoPath).pull().run()
} catch ShellError.commandNotFound(let cmd) {
    print("\(cmd) is not installed")
} catch ShellError.exitFailure(_, let output) {
    print("Pull failed:", output.stderr)
} catch ShellError.timeout(let cmd, let duration, _) {
    print("\(cmd) timed out after \(duration)s")
}
```

## Writing Testable Code

Inject ``MockExecutor`` via ``ShellContext`` to test without spawning real
processes. The same executor is used by typed families and raw commands, so
tests see every call:

```swift
// In production code — accept a ShellContext
func buildProject(context: ShellContext) async throws -> String {
    let output = try await Command("swift", "build").run(in: context)
    return output.stdout
}

// In tests — MockExecutor
@Test func buildProjectReturnsMockedOutput() async throws {
    let mock = MockExecutor(stdout: "Build complete.\n")
    let context = ShellContext(executor: mock)
    let result = try await buildProject(context: context)
    #expect(result == "Build complete.\n")
}
```

For richer scenarios, supply a closure:

```swift
actor InvocationRecorder {
    var invocations: [Command] = []
    func record(_ command: Command) { invocations.append(command) }
}
let recorder = InvocationRecorder()
let mock = MockExecutor { command, _ in
    await recorder.record(command)
    return ShellOutput(stdout: "ok\n", stderr: "", exitCode: 0)
}
let context = ShellContext(executor: mock)
```

## Timeouts and Cancellation

Set timeouts at the context level, per typed client, or per raw command. All levels accept `TimeInterval` (seconds):

```swift
// Context default — applied to every command unless overridden
let context = ShellContext(defaultTimeout: 30)

// Per typed client
try await Git(context: context).timeout(60).fetch().run()

// Per raw command
try await Command("curl", apiURL)
    .timeout(10)
    .run(in: context)
```

Swift task cancellation propagates automatically. Cancelling the enclosing `Task` sends SIGTERM then SIGKILL to the subprocess, and `run()` throws ``ShellError/cancelled(command:partialOutput:)``:

```swift
let task = Task {
    try await Command("long-running-tool").run(in: context)
}
task.cancel()  // subprocess is terminated; throws ShellError.cancelled
```

## Concurrent Commands

Typed families and raw commands are `Sendable` — compose them with Swift
Concurrency:

```swift
let repoPaths = ["/path/a", "/path/b", "/path/c"]
let git = Git(context: context)

try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
    for path in repoPaths {
        group.addTask {
            try await git.workingDirectory(path).fetch().run()
        }
    }
    for try await result in group {
        print("Fetched from", result.remote)
    }
}
```
