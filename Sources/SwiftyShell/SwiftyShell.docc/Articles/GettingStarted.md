# Getting Started with SwiftyShell

Add SwiftyShell to your package, run your first command, and understand the core concepts.

## Overview

SwiftyShell replaces ad-hoc `Process` or shell-string wrappers with a strongly-typed,
fluent API. Every command is a value — not a raw string — so the compiler catches typos,
and tests can run without spawning real processes.

## Installation

Add SwiftyShell to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftyShell.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "MyTool",
        dependencies: ["SwiftyShell"]
    ),
]
```

## Running Your First Command

Every operation starts with a ``ShellContext`` and a ``Command``:

```swift
import SwiftyShell

// Create a shared context — this is the "environment" for all commands
let context = ShellContext()

// Run a simple command
let output = try await Command("echo", "Hello, SwiftyShell!").run(in: context)
print(output.stdout) // Hello, SwiftyShell!
```

`run()` is `async throws`. Wrap calls in `Task` or use them from an async entry point.

## Fluent Configuration

Commands are immutable value types. Use the fluent API to build up configuration — each
method returns a new copy:

```swift
let output = try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .env("DEBUG", "true")
    .workingDirectory("/var/app")
    .timeout(300)
    .run(in: context)
```

## Reading Output

``ShellOutput`` captures stdout, stderr, and the exit code:

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

All failures surface as ``ShellError``. Catch specific cases to react appropriately:

```swift
do {
    let output = try await Command("git", "push").run(in: context)
} catch ShellError.commandNotFound(let cmd) {
    print("\(cmd) is not installed")
} catch ShellError.exitFailure(_, let output) {
    print("Push failed with exit code:", output.exitCode)
    print("Stderr:", output.stderr)
} catch ShellError.timeout(let cmd, let duration, _) {
    print("\(cmd) timed out after \(duration)s")
}
```

## Pipelines

Connect two or more commands with `.pipe(to:)`:

```swift
// ls -la | grep .swift | wc -l
let output = try await Command("ls", "-la")
    .pipe(to: Grep(".swift").command())
    .pipe(to: Command("wc", "-l"))
    .run(in: context)

let count = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
print("Swift files:", count)
```

## Redirecting Output

Use ``OutputDestination`` to write command output to a file or discard it:

```swift
// Write build log to a file
try await Command("swift", "build", "--verbose")
    .stdout(.file(path: "/tmp/build.log", append: false))
    .stderr(.file(path: "/tmp/build.log", append: true))
    .run(in: context)

// Discard stderr to suppress noise
try await Command("make", "clean")
    .stderr(.discard)
    .run(in: context)
```

## Typed Command Families

For common tools, use the typed wrappers instead of raw `Command`:

```swift
// Git
let status = try await Git(context: context)
    .workingDirectory("/path/to/repo")
    .status()
    .run()

// Grep
let matches = try await Grep("TODO", context: context)
    .recursive()
    .lineNumbers()
    .file("Sources/")
    .run()

// File system
try await Mkdir(context: context).parents().directory("/tmp/output").run()
try await Cp(context: context).recursive().source("build/").destination("/tmp/dist").run()
```

## Writing Testable Code

Inject ``MockExecutor`` via ``ShellContext`` to test without spawning real processes:

```swift
// In production code — accept a ShellContext
func buildProject(context: ShellContext) async throws -> String {
    let output = try await Command("swift", "build").run(in: context)
    return output.stdout
}

// In tests — use MockExecutor
func testBuildProject() async throws {
    let mock = MockExecutor(stdout: "Build complete.\n")
    let context = ShellContext(executor: mock)
    let result = try await buildProject(context: context)
    XCTAssertEqual(result, "Build complete.\n")
}
```

For richer test scenarios, supply a closure:

```swift
var invocations: [Command] = []
let mock = MockExecutor { command, _ in
    invocations.append(command)
    return ShellOutput(stdout: "ok\n", stderr: "", exitCode: 0)
}
let context = ShellContext(executor: mock)
```

## Concurrent Commands

Use Swift Concurrency to run multiple commands in parallel:

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
