# SwiftyShell Specification

## Vision

SwiftyShell provides type-safe shell support in Swift.

The goal is not just to run subprocesses safely, but to model common shell concepts as Swift types:

- commands
- arguments
- executable resolution
- environment and working directory
- pipelines
- redirection
- deferred workflows
- typed command families such as `Git`, `XcodeBuild`, and `Xcrun`

The library uses the `Subprocess` API introduced in Swift 6.1 as the execution engine, but the public API is a Swift-first shell DSL rather than a thin wrapper around raw shell strings.

## Scope: Version 1

### Platforms

- **macOS**: 15.0+
- **Linux**: Ubuntu 22.04 (glibc 2.35+)
- **Swift**: 6.1+

### In Scope

- Type-safe command construction with explicit executable and arguments
- Shared shell execution context with default configuration
- Per-command override of executable path, environment, working directory, timeout, and output limit
- Buffered stdout/stderr capture
- Explicit pipeline composition
- Explicit stdout/stderr redirection
- Deferred fluent workflows for typed command families
- Typed command-family support starting with `Git`, `Grep`, `XcodeBuild`, `Xcrun`/`Simctl`, and common utility wrappers such as `Ls`, `Cp`, `Mv`, `Mkdir`, `Pwd`, `Rm`, and `Jq`
- Async/await execution
- Protocol-based execution seams for testing and dependency injection
- Comprehensive documentation with runnable examples

### Out of Scope (v1)

- Raw shell-script strings as a primary execution model
- Automatic parsing of shell syntax from a single string
- Interactive stdin handling
- Permission elevation (`sudo`, etc.)
- GUI integration
- Windows support
- Plugin or multi-package command distribution

Raw shell strings may be considered later as an explicitly unsafe escape hatch, but they are not part of v1's public API.

---

## Core API & Execution Model

### Primary Types

#### `ShellContext`

`ShellContext` is the shared runtime configuration for shell execution. It is not the command surface itself.

```swift
public struct ShellContext: Sendable {
  public init(
    executor: any CommandExecutor = SubprocessExecutor(),
    searchPaths: [String] = ShellContext.defaultSearchPaths,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    workingDirectory: String? = nil,
    defaultTimeout: TimeInterval? = nil,
    defaultOutputLimit: Int = 10_485_760  // 10 MiB
  )
}
```

Responsibilities:

- stores the executor implementation
- stores shell-wide defaults
- controls executable lookup paths
- provides a stable execution environment for commands and workflows

Typical usage:

```swift
let context = ShellContext()
```

#### `Command`

`Command` is the core value type for representing a single executable invocation.

```swift
public struct Command: Sendable {
  public init(_ executable: String, _ arguments: String...)

  public func executable(_ path: String) -> Self
  public func arg(_ value: String) -> Self
  public func args(_ values: [String]) -> Self

  public func env(_ name: String, _ value: String) -> Self
  public func env(_ values: [String: String]) -> Self

  public func workingDirectory(_ path: String) -> Self
  public func timeout(_ seconds: TimeInterval) -> Self
  public func outputLimit(_ bytes: Int) -> Self

  public func stdout(_ destination: OutputDestination) -> Self
  public func stderr(_ destination: OutputDestination) -> Self

  public func pipe(to next: Command) -> Pipeline

  public func run(in context: ShellContext = .init()) async throws -> ShellOutput
}
```

Typical usage:

```swift
let output = try await Command("pwd").run(in: context)
```

#### `Pipeline`

`Pipeline` represents explicitly connected shell commands.

```swift
public struct Pipeline: Sendable {
  public func pipe(to next: Command) -> Self
  public func run(in context: ShellContext = .init()) async throws -> ShellOutput
}
```

Typical usage:

```swift
let output = try await Command("ls", "-la")
  .pipe(to: Grep(".swift").command())
  .run(in: context)
```

#### `OutputDestination`

`OutputDestination` models output behavior explicitly instead of relying on raw shell redirection syntax.

```swift
public enum OutputDestination: Sendable {
  case capture
  case discard
  case file(path: String, append: Bool)
}
```

When `append` is `false`, the file is created if it does not exist, or truncated to zero length before writing begins. When `append` is `true`, output is written to the end of the file; the file is created if it does not exist.

#### `ShellOutput`

`ShellOutput` captures process results.

```swift
public struct ShellOutput: Sendable {
  public var stdout: String
  public var stderr: String
  public var exitCode: Int32
  public var isSuccess: Bool
}
```

In v1, stdout and stderr are always captured unless explicitly redirected elsewhere.
If a stream produces no text, the corresponding value is an empty string.

#### `ToolConfigurableCommandFamily`

`ToolConfigurableCommandFamily` is the shared protocol for typed command families that support standard tool configuration overrides.

```swift
public protocol ToolConfigurableCommandFamily: Sendable {
  var context: ShellContext { get }

  func updatingConfiguration(
    _ update: (ToolConfiguration) -> ToolConfiguration
  ) -> Self
}
```

Conforming types inherit fluent helpers for:

- `executable(_:)`
- `env(_:_:)`
- `env(_:)`
- `workingDirectory(_:)`
- `timeout(_:)`
- `outputLimit(_:)`

#### `OutputRedirectingCommandFamily`

`OutputRedirectingCommandFamily` extends `ToolConfigurableCommandFamily` with shared stdout/stderr redirection behavior.

```swift
public protocol OutputRedirectingCommandFamily: ToolConfigurableCommandFamily {
  func settingStdoutDestination(_ destination: OutputDestination) -> Self
  func settingStderrDestination(_ destination: OutputDestination) -> Self
}
```

Conforming types inherit:

- `stdout(_:)`
- `stderr(_:)`

#### `RunnableCommandFamily`

`RunnableCommandFamily` extends `OutputRedirectingCommandFamily` for typed clients that materialize a `Command`.

```swift
public protocol RunnableCommandFamily: OutputRedirectingCommandFamily {
  func command() -> Command
}
```

Conforming types inherit a shared `run()` implementation.

#### `ShellError`

`ShellError` models all public failure modes.

```swift
public enum ShellError: Error, LocalizedError {
  case commandNotFound(String)
  case exitFailure(command: String, output: ShellOutput)
  case timeout(command: String, duration: TimeInterval, partialOutput: ShellOutput)
  case decodingError(command: String, stream: StreamKind)
  case outputLimitExceeded(command: String, limit: Int, partialOutput: ShellOutput)
  case cancelled(command: String, partialOutput: ShellOutput)
  case spawnError(command: String, reason: String)
  case workflowConditionFailed(description: String)
}
```

#### `StreamKind`

`StreamKind` identifies which captured output stream failed to decode. It is used exclusively by `ShellError.decodingError` and is defined as a top-level public type for clarity in error messages and pattern matching.

```swift
public enum StreamKind: Sendable {
  case stdout
  case stderr
}
```

#### `Workflow<Value>`

`Workflow` is the generic deferred chaining primitive used by typed command families.

```swift
public struct Workflow<Value>: Sendable {
  public consuming func run() async throws -> Value

  public func map<T>(
    _ transform: @escaping @Sendable (Value) throws -> T
  ) -> Workflow<T>

  public func map<T>(_ keyPath: KeyPath<Value, T>) -> Workflow<T>

  public func require(
    _ predicate: @escaping @Sendable (Value) throws -> Bool,
    else error: @autoclosure @escaping @Sendable () -> Error
  ) -> Workflow<Value>

  public func require<T: Equatable>(
    _ keyPath: KeyPath<Value, T>,
    equals expected: T,
    else error: @autoclosure @escaping @Sendable () -> Error
  ) -> Workflow<Value>
}
```

Semantics:

- action steps are queued, not executed immediately
- execution starts when `run()` is awaited
- transformation and condition helpers compose on queued results
- typed command-family workflows may expose additional domain-specific steps
- workflows are single-use execution plans; `run()` consumes the workflow value
- to repeat the same logical operation, rebuild the workflow from the source client or command family
- concurrent tasks must each create and run their own workflow values rather than sharing one in-flight workflow instance

#### `Git`

`Git` is the first typed command-family client in v1. It is built on the same execution model as `Command`, but exposes domain-specific operations and typed results.

```swift
public struct Git: Sendable {
  public init(context: ShellContext = .init())

  public func executable(_ path: String) -> Self
  public func env(_ name: String, _ value: String) -> Self
  public func env(_ values: [String: String]) -> Self
  public func workingDirectory(_ path: String) -> Self
  public func timeout(_ seconds: TimeInterval) -> Self
  public func outputLimit(_ bytes: Int) -> Self

  public func status() -> GitStatusWorkflow
  public func pull() -> Workflow<GitPullResult>
  public func fetch() -> Workflow<GitFetchResult>
}
```

#### `GitStatus`

`GitStatus` is the first typed result model in v1.

```swift
public struct GitStatus: Sendable {
  public var state: GitWorkingTreeState
  public var branch: String?
  public var upstream: String?
  public var hasStagedChanges: Bool
  public var hasUnstagedChanges: Bool
  public var hasUntrackedFiles: Bool
}

public enum GitWorkingTreeState: Sendable {
  case noChanges
  case dirty
}

public struct GitPullResult: Sendable {
  public var branch: String
  public var upstream: String?
}

public struct GitFetchResult: Sendable {
  public var remote: String
}
```

#### `Grep`

`Grep` provides a typed wrapper over `grep` for the common filtering cases where literal matching should be explicit and regex mode should be opt-in.

```swift
public enum GrepPattern: Sendable {
  case literal(String)
  case regularExpression(String)
}

public struct Grep: Sendable {
  public init(_ pattern: String, context: ShellContext = .init())
  public static func regex(_ pattern: String, context: ShellContext = .init()) -> Self

  public func executable(_ path: String) -> Self
  public func env(_ name: String, _ value: String) -> Self
  public func env(_ values: [String: String]) -> Self
  public func workingDirectory(_ path: String) -> Self
  public func timeout(_ seconds: TimeInterval) -> Self
  public func outputLimit(_ bytes: Int) -> Self

  public func stdout(_ destination: OutputDestination) -> Self
  public func stderr(_ destination: OutputDestination) -> Self

  public func ignoreCase(_ enabled: Bool = true) -> Self
  public func invertMatch(_ enabled: Bool = true) -> Self
  public func lineNumbers(_ enabled: Bool = true) -> Self
  public func file(_ path: String) -> Self
  public func files(_ paths: [String]) -> Self

  public func command() -> Command
  public func run() async throws -> ShellOutput
}
```

Typical usage:

```swift
let output = try await Command("printf", "alpha\nbeta42\ngamma\n")
  .pipe(to: Grep.regex(#"beta[0-9]+"#).command())
  .run(in: context)
```

#### Common Utility Wrappers

SwiftyShell also exposes typed wrappers for frequently used shell utilities when a discoverable fluent API is more convenient than assembling raw `Command` values every time.

```swift
public struct Ls: Sendable { ... }
public struct Cp: Sendable { ... }
public struct Mv: Sendable { ... }
public struct Mkdir: Sendable { ... }
public struct Pwd: Sendable { ... }
public struct Rm: Sendable { ... }

public struct JqArgument: Sendable {
  public init(name: String, value: String)
}

public struct Jq: Sendable { ... }
```

These wrappers follow the same conventions as the existing typed clients:

- `init(context:)` to bind a `ShellContext`
- private state storage with non-`mutating` fluent methods that return updated values
- `RunnableCommandFamily` conformance for shared config, redirection, and `run()` support
- fluent config overrides for executable, environment, working directory, timeout, and output limit
- explicit `stdout(_:)` and `stderr(_:)` redirection
- `command()` for command construction inspection
- `run()` for async execution

Typical usage:

```swift
try await Cp(context: context)
  .source(sourcePath)
  .destination(destinationPath)
  .run()

let output = try await Jq(".items[]")
  .rawOutput()
  .file(jsonPath)
  .run()
```

#### `Xcrun`

`Xcrun` provides a typed wrapper over `xcrun` and can be used directly for tool lookup/execution or as the entry point for simulator-specific `simctl` commands.

```swift
public struct Xcrun: Sendable {
  public init(context: ShellContext = .init())

  public func executable(_ path: String) -> Self
  public func env(_ name: String, _ value: String) -> Self
  public func env(_ values: [String: String]) -> Self
  public func workingDirectory(_ path: String) -> Self
  public func timeout(_ seconds: TimeInterval) -> Self
  public func outputLimit(_ bytes: Int) -> Self

  public func stdout(_ destination: OutputDestination) -> Self
  public func stderr(_ destination: OutputDestination) -> Self

  public func option(_ option: XcrunOption) -> Self
  public func options(_ values: [XcrunOption]) -> Self
  public func tool(_ value: String) -> Self
  public func trailingArgument(_ value: String) -> Self
  public func trailingArguments(_ values: [String]) -> Self

  public func simctl() -> Simctl
  public func command() -> Command
  public func run() async throws -> ShellOutput
}
```

Typical usage:

```swift
let output = try await Xcrun(context: context)
  .option(.sdk("iphonesimulator"))
  .tool("simctl")
  .trailingArguments(["list", "devices"])
  .run()
```

#### `Simctl`

`Simctl` layers on top of `Xcrun` and provides typed entry points for common simulator-control commands while preserving an escape hatch for custom subcommands.

```swift
public struct Simctl: Sendable {
  public init(context: ShellContext = .init())

  public func command(_ value: SimctlCommand) -> Self
  public func custom(_ subcommand: String, arguments: [String] = []) -> Self
  public func arg(_ value: String) -> Self
  public func args(_ values: [String]) -> Self

  public func list(_ target: SimctlListTarget? = nil, json: Bool = false, searchTerm: String? = nil) -> Self
  public func boot(_ device: String) -> Self
  public func shutdown(_ devices: [String]) -> Self
  public func erase(_ devices: [String]) -> Self
  public func install(_ device: String, appAt path: String) -> Self
  public func launch(_ device: String, bundleIdentifier: String) -> Self

  public func builtCommand() -> Command
  public func run() async throws -> ShellOutput
}
```

`GitStatusWorkflow` is a git-specific workflow value layered on top of the generic workflow core.

```swift
public struct GitStatusWorkflow: Sendable {
  public consuming func run() async throws -> GitStatus

  public func map<T>(
    _ transform: @escaping @Sendable (GitStatus) throws -> T
  ) -> Workflow<T>

  public func map<T>(_ keyPath: KeyPath<GitStatus, T>) -> Workflow<T>

  public func require(
    _ predicate: @escaping @Sendable (GitStatus) throws -> Bool,
    else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(description: "Git workflow condition failed")
  ) -> GitStatusWorkflow

  public func require<T: Equatable>(
    _ keyPath: KeyPath<GitStatus, T>,
    equals expected: T,
    else error: @autoclosure @escaping @Sendable () -> Error = ShellError.workflowConditionFailed(description: "Git workflow condition failed")
  ) -> GitStatusWorkflow

  public func pull() -> Workflow<GitPullResult>
  public func fetch() -> Workflow<GitFetchResult>
}
```

`pull()` throws `ShellError.exitFailure` when the pull fails (e.g. local uncommitted changes conflict with the incoming merge, or the remote is unreachable). `fetch()` throws `ShellError.exitFailure` when the remote cannot be contacted or authentication fails.

Typical usage:

```swift
try await Git(context: context)
  .workingDirectory(repoPath)
  .status()
  .require(\.state, equals: .noChanges)
  .pull()
  .run()
```

### Execution Flow

SwiftyShell has two complementary execution styles:

1. **Core shell execution**
   - build a `Command` or `Pipeline`
   - override config as needed
   - run it in a `ShellContext`

2. **Typed workflow execution**
   - start from a typed client such as `Git`
   - queue domain operations fluently
   - await the terminal `run()`

This split keeps the core shell model general while allowing high-level typed workflows where they provide real value.

---

## Execution Behavior

### Executable Resolution

- A `Command` starts with an executable identifier such as `"git"` or `"pwd"`.
- At runtime, the executor resolves that identifier against:
  - an explicit per-command `.executable(...)` override, if present
  - otherwise the `ShellContext.searchPaths`
- Typed clients such as `Git` follow the same precedence rules.
- Per-command or per-client executable overrides always win over shell-wide defaults.

### Environment & Working Directory

- `ShellContext` provides default environment variables and working directory behavior.
- `Command` and typed clients may override either independently.
- Environment merge semantics:
  - `env(_:_:)` and `env(_:)` set keys that override any matching key from the context environment.
  - Keys present only in the context environment pass through unchanged.
- Working directory defaults to the process cwd when neither the context nor the command sets one.

### Output Handling

- Output is buffered in memory by default.
- Default maximum captured output size is 10 MiB (10,485,760 bytes), configurable via `ShellContext.defaultOutputLimit`.
- `Command.outputLimit(_:)` and typed client `.outputLimit(_:)` override the default for one invocation or workflow chain.
- Exceeding the limit throws `ShellError.outputLimitExceeded`.
- stdout and stderr are decoded as UTF-8 when captured.
- Invalid UTF-8 raises `ShellError.decodingError`.
- Redirected output is not also captured unless the API explicitly documents tee-like behavior in the future.

### Exit Code Behavior

- `Command.run(...)` throws `ShellError.exitFailure` for non-zero exit by default.
- `ShellError.exitFailure` always includes the full captured `ShellOutput`.
- This preserves stdout, stderr, and exit code for script logic and diagnostics.

### Pipelines

- Pipelines are explicit values, not parsed shell strings.
- `pipe(to:)` connects stdout from one command to stdin of the next.
- Exit semantics for v1:
  - if any stage exits non-zero, the pipeline throws `ShellError.exitFailure`
  - the `command` payload identifies the failing stage
  - the `output` payload preserves the captured stdout/stderr available at the point of failure
  - once a stage failure is detected, remaining stages are terminated
- This makes pipeline execution fail-safe by default for automation use cases; alternative failure modes, if added later, must be explicit opt-ins.

### Concurrent Execution

SwiftyShell does not provide a dedicated concurrent batch API. Concurrent execution is expressed using standard Swift structured concurrency.

`Command`, `Pipeline`, `Workflow`, and all typed clients are `Sendable` and share no mutable state between calls, making them safe to use across concurrent tasks.

```swift
// Two independent git operations concurrently
let git = Git(context: context)
async let status = git.workingDirectory(repoA).status().run()
async let fetchResult = git.workingDirectory(repoB).fetch().run()
let (s, f) = try await (status, fetchResult)

// N repos fetched concurrently
try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
    for path in repoPaths {
        group.addTask { try await git.workingDirectory(path).fetch().run() }
    }
    for try await _ in group {}
}
```

Cancelling the parent Swift task cancels all in-flight child `run()` calls; each spawned process receives the `SIGTERM → SIGKILL` sequence and throws `ShellError.cancelled` with any output captured before termination.

### Timeout & Cancellation

- Timeouts may be set at the shell context, command, or typed client level.
- The most specific timeout wins.
- If the timeout is exceeded, the process receives `SIGTERM`. If the process does not exit within a short grace period (implementation-defined, recommended 2 seconds), `SIGKILL` is sent. `ShellError.timeout` is then thrown with any stdout/stderr captured before termination.
- Swift task cancellation follows the same two-step termination sequence (`SIGTERM` → `SIGKILL`) and throws `ShellError.cancelled` with any stdout/stderr captured before termination.
- stdin is always closed (redirected to `/dev/null`) for all spawned processes. Commands that block on stdin will receive EOF immediately.

### Deferred Workflow Semantics

- Typed workflow steps queue operations until `run()` is awaited.
- Workflow transformations such as `map` and `require` do not trigger execution by themselves.
- If a workflow condition fails, the chain throws the supplied error.
- Domain-specific follow-up actions such as `GitStatusWorkflow.pull()` may depend on prior typed workflow results.

---

## Type Safety

"Type-safe shell support" in SwiftyShell means:

1. **No raw shell strings as the main API**
   Users compose commands, pipelines, and workflows as Swift values rather than passing opaque strings to `sh`.

2. **Explicit executable and argument boundaries**
   Executable names, arguments, environment values, and output destinations are modeled separately.

3. **Typed shell semantics**
   Pipelines, redirections, and workflow gates are represented directly in Swift.

4. **Typed command families where it matters**
   Domain APIs such as `Git` return typed values like `GitStatus` instead of unstructured strings.

5. **Fluent deferred composition**
   Workflow chains are validated and composed before execution.

6. **Concrete error handling**
   Failures are represented as public error cases, not loosely structured strings.

This does **not** mean:

- every executable on the system gets its own Swift type in v1
- shell parsing from raw script text is supported
- all command output is automatically parsed into structured types

---

## Command Families & Fluent API Design

### Core Rule

Simple shell commands should remain simple.

For commands where the user only needs to run an executable with arguments, `Command` is the primary API:

```swift
try await Command("mkdir")
  .arg("-p")
  .arg(outputDirectory)
  .run(in: context)
```

Typed command-family clients are added only when they provide meaningful value over raw `Command` usage.

### Initial Typed Families

#### `Git`

`Git` is included in v1 because it benefits from:

- typed status parsing
- frequent developer automation usage
- conditional follow-up steps
- clearer intent than raw `Command("git", ...)`

Example:

```swift
let git = Git(context: context)

try await git
  .workingDirectory(repoPath)
  .status()
  .require { $0.state == .noChanges }
  .pull()
  .run()
```

#### `XcodeBuild`

`XcodeBuild` is included when callers want a typed, discoverable way to compose the large `xcodebuild` option surface without falling back to raw string flags.

Example:

```swift
let output = try await XcodeBuild(context: context)
  .option(.workspace("MyApp.xcworkspace"))
  .option(.scheme("MyApp"))
  .option(.destination("platform=iOS Simulator,name=iPhone 17"))
  .buildSetting("SWIFT_ENABLE_EXPLICIT_MODULES", "NO")
  .trailingArgument("build")
  .run()
```

### Generic Fluent Helpers

Fluent helper methods should be shared whenever possible.

v1 includes:

- closure-based `map`
- key-path-based `map`
- closure-based `require`
- key-path equality `require`

These helpers belong to workflow types, not to raw `ShellOutput`.

### Command-Family Authoring

Typed command families should share fluent infrastructure through protocols instead of re-implementing the same configuration surface repeatedly.

- use `ToolConfigurableCommandFamily` for standard executable/environment/timeout overrides
- use `OutputRedirectingCommandFamily` when the command supports explicit stdout/stderr destinations
- use `RunnableCommandFamily` when the type builds a `Command` and should inherit `run()`
- keep family-specific state private and derive argv in `command()`
- add builder and execution tests for each new family

### Why Helpers Are Not `shell.pwd()` or `shell.git`

`ShellContext` is infrastructure, not a namespace for every command.

That means:

- `Command("pwd")` is the default way to express simple shell commands
- `Git(context: context)` is the default way to express typed git operations
- `XcodeBuild(context: context)` is the default way to express typed `xcodebuild` invocations
- users are not forced into redundant APIs such as `shell.git` or `shell.pwd`

This keeps the API closer to how developers think about shell work:

- a shell context/configuration
- command values
- typed workflows when useful

---

## Testing & Mockability

### Protocol-Based Seams

Execution is abstracted behind a protocol:

```swift
public protocol CommandExecutor: Sendable {
  func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput
  func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
}

public struct SubprocessExecutor: CommandExecutor { ... }
public struct MockExecutor: CommandExecutor { ... }
```

`ShellContext` stores the executor so both low-level commands and typed clients use the same injectable runtime.

### Testing Requirements

- Unit tests for all error paths:
  - timeout
  - non-zero exit
  - missing command
  - invalid UTF-8
  - output limit exceeded
  - cancellation
- Unit tests for deferred workflow behavior:
  - workflows do not execute before `run()`
  - `require` throws on mismatch
  - key-path helpers behave correctly
  - executable overrides propagate through typed workflows
- Integration tests on both macOS and Linux using real commands
- Mocking tests demonstrating injected executors work for both `Command` and `Git`

---

## Documentation Requirements

### Content

1. **README**
   - overview
   - installation via SwiftPM
   - quick-start examples for `Command`, `Pipeline`, and `Git`
2. **API Reference**
   - doc comments for all public types and methods
3. **Usage Guide**
   - simple commands
   - pipelines
   - redirection
   - environment and working directory
   - timeouts and cancellation
   - typed git workflows
4. **Testing Guide**
   - shell context injection
   - mock executors
   - workflow testing
5. **Examples**
   - runnable automation-focused examples in the repository

### Documentation Rules

- examples must use typed APIs, not raw shell strings
- command-family docs must show both closure-based and key-path-based fluent helpers where relevant
- docs should explain when to use `Command` versus a typed client like `Git`

---

## Package Structure

```
SwiftyShell/
├── Sources/
│   └── SwiftyShell/
│       ├── Core/
│       │   ├── ShellContext.swift
│       │   ├── Command.swift
│       │   ├── Pipeline.swift
│       │   ├── OutputDestination.swift
│       │   ├── ShellOutput.swift
│       │   ├── ShellError.swift
│       │   ├── CommandExecutor.swift
│       │   └── Workflow.swift
│       ├── Git/
│       │   ├── Git.swift
│       │   ├── GitStatus.swift
│       │   ├── GitStatusWorkflow.swift
│       │   └── GitParsers.swift
│       ├── Common/
│       │   ├── Cp.swift
│       │   ├── Jq.swift
│       │   ├── Ls.swift
│       │   ├── Mkdir.swift
│       │   ├── Mv.swift
│       │   ├── Pwd.swift
│       │   └── Rm.swift
│       ├── XcodeBuild/
│       │   ├── XcodeBuild.swift
│       │   └── XcodeBuildOption.swift
│       └── Xcrun/
│           ├── Simctl.swift
│           ├── SimctlCommand.swift
│           ├── Xcrun.swift
│           └── XcrunOption.swift
│       └── Internal/
│           └── Execution/
│               └── SubprocessExecutor.swift
├── .claude/
│   └── skills/
│       └── swiftyshell.md
└── Tests/
    └── SwiftyShellTests/
        ├── Core/
        ├── Pipelines/
        └── Git/
```

This remains a single public library product. Internal folders organize shell semantics and typed command families without forcing users to import multiple modules.

---

## Distribution Model

SwiftyShell ships as a single Swift Package with a single public library product.

### Public Product

- Library product: `SwiftyShell`
- User dependency reference: `.product(name: "SwiftyShell", package: "SwiftyShell")`
- User import: `import SwiftyShell`

---

## SwiftyShell Agent Skill

The SwiftyShell skill teaches AI agents how to generate correct, strongly-typed SwiftyShell code. An agent with this skill can translate a plain-language shell task description into idiomatic SwiftyShell Swift without guessing API shapes or falling back to raw shell strings.

### Skill Location

```
.claude/skills/swiftyshell.md
```

### Skill Content

The skill file must include:

1. **API reference summary** — the full public surface of `ShellContext`, `Command`, `Pipeline`, `OutputDestination`, `ShellOutput`, `ShellError`, `Workflow`, `Git`, `GitStatus`, `GitStatusWorkflow`, `GitPullResult`, and `GitFetchResult`, copied verbatim from the spec type signatures.

2. **Type selection rules** — a decision tree the agent follows before writing any code:
   - Is this a git operation supported by the typed `Git` API? → use `Git`
   - Is this a git operation not yet modeled by `Git`? → use `Command("git", ...)`
   - Does the operation need typed output or conditional follow-up? → use a typed workflow client
   - Is this any other command? → use `Command`
   - Are two or more commands chained by pipe? → use `.pipe(to:)` to build a `Pipeline`
   - Does the command write output to a file? → use `.stdout(.file(path:append:))` on `Command`

3. **Code generation rules** the agent must follow:
   - Always `import SwiftyShell`
   - All `run()` calls are `async throws` — callers must be in an `async` context
   - Never construct raw shell strings as the primary execution model
   - Prefer `Git` when the operation is covered by the typed git API; otherwise use `Command("git", ...)`
   - Prefer key-path `require` over closure `require` when checking a single property
   - Prefer `async let` / `TaskGroup` for concurrent runs — do not serialize what can run in parallel
   - Always pass an explicit `ShellContext` rather than relying on the default `.init()`

4. **Worked examples** covering each major pattern:

```swift
// Simple command
let output = try await Command("mkdir").arg("-p").arg(outputDir).run(in: context)

// Pipeline
let output = try await Command("ls", "-la")
  .pipe(to: Grep(".swift").command())
  .run(in: context)

// Redirect stdout to file
try await Command("xcodebuild", "-scheme", "MyApp")
  .stdout(.file(path: logPath, append: false))
  .run(in: context)

// Git status check then pull
try await Git(context: context)
  .workingDirectory(repoPath)
  .status()
  .require(\.state, equals: .noChanges)
  .pull()
  .run()

// Concurrent git fetch across multiple repos
let git = Git(context: context)
try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
    for path in repoPaths {
        group.addTask { try await git.workingDirectory(path).fetch().run() }
    }
    for try await _ in group {}
}

// Environment override on top of inherited context
try await Command("ruby", "deploy.rb")
  .env("RAILS_ENV", "production")
  .run(in: context)
```

5. **Error handling reference** — a table mapping each `ShellError` case to its cause and how to handle it in automation scripts:

| Case | Cause | Typical response |
|---|---|---|
| `commandNotFound` | executable not on search path | check `ShellContext.searchPaths` or use `.executable(_:)` override |
| `exitFailure` | non-zero exit code | inspect `output.stderr`; decide whether to retry or abort |
| `timeout` | command exceeded time limit | inspect `partialOutput`, increase timeout, or investigate the hanging command |
| `outputLimitExceeded` | output exceeded configured limit | raise `outputLimit` or redirect to file |
| `decodingError` | output is not valid UTF-8 | redirect output to file and read as `Data` |
| `cancelled` | parent Swift task was cancelled | inspect `partialOutput` if needed, then propagate cancellation |
| `workflowConditionFailed` | a `require` predicate returned false | handle the specific workflow gate that failed |

### Skill Maintenance

The skill file must be updated whenever:

- a new typed command-family client is added (e.g. a future `Docker`, `Homebrew`)
- a new method is added to an existing client
- error cases are added or renamed
- execution semantics change (e.g. pipeline exit behavior, environment merge rules)

The skill is a derived artifact — it must accurately reflect the implemented API, not the spec. Update it as part of the same PR that ships the API change.

---

## Deferred Features (v2+)

- Explicit unsafe raw shell-string escape hatch
- Alternative pipeline failure modes as explicit opt-ins
- Interactive stdin
- Additional typed command families beyond `Git` and `XcodeBuild`
- Alternative packaging if command families grow substantially
- Windows support

---

## Acceptance Criteria

### Code

- [ ] `ShellContext`, `Command`, `Pipeline`, `Workflow`, and `Git` are publicly documented
- [ ] All public types conform to `Sendable`
- [ ] All error paths are tested:
  - timeout
  - exit failure
  - missing command
  - decoding error
  - output limit exceeded
  - cancellation
  - workflow condition failure
- [ ] Commands can override executable path, environment, working directory, timeout, and output limit
- [ ] Pipelines and redirection are modeled without raw shell-string parsing
- [ ] Pipeline execution fails when any stage exits non-zero
- [ ] Workflow execution is single-use and documented as such
- [ ] Typed git workflows support closure-based and key-path-based conditions

### Documentation

- [ ] README includes examples for `Command`, `Pipeline`, and `Git`
- [ ] Usage guide explains when to use generic commands versus typed clients
- [ ] Workflow docs show deferred execution semantics clearly
- [ ] Testing guide explains context and executor injection

### Agent Skill

- [ ] `.claude/skills/swiftyshell.md` exists and reflects the implemented public API
- [ ] Skill includes type selection rules, code generation rules, worked examples, and error reference table
- [ ] Skill is updated in the same PR as any public API change

### Build & Integration

- [ ] Builds with Swift 6.1+ on both macOS and Linux
- [ ] Zero external dependencies beyond Foundation/Subprocess
- [ ] SwiftPM integration requires no custom build steps
