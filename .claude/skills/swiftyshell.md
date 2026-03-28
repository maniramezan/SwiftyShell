# SwiftyShell Skill

This skill serves two purposes:

1. **Code generation** — generate correct, strongly-typed SwiftyShell code from plain-language task descriptions
2. **Contribution guidance** — add new command families following established conventions

---

## Part 1: Generating SwiftyShell Code

### Type Selection Rules

Before writing any code, follow this decision tree:

1. Is this a git operation supported by the typed `Git` API (`status()`, `pull()`, `fetch()`)?
   → Use `Git`
2. Is this a git operation NOT covered by the typed `Git` API?
   → Use `Command("git", ...)`
3. Does the operation need typed output, structured results, or conditional follow-up?
   → Use the appropriate typed client (`Git`, `Grep`, `XcodeBuild`, `Xcrun`/`Simctl`)
4. Are two or more commands chained by pipe?
   → Use `.pipe(to:)` to build a `Pipeline`
5. Does the command write output to a file?
   → Use `.stdout(.file(path:append:))` on the command
6. Is this any other command?
   → Use `Command`

### API Reference

#### ShellContext

```swift
public enum ShellPlatform: Sendable {
    case macOS
    case linux

    public static let current: ShellPlatform
    public var defaultSearchPaths: [String] { get }
}

public struct ShellContext: Sendable {
    public static let defaultSearchPaths: [String]

    public static func defaultSearchPaths(
        environment: [String: String],
        platform: ShellPlatform = .current
    ) -> [String]

    public init(
        executor: any CommandExecutor = SubprocessExecutor(),
        searchPaths: [String] = ShellContext.defaultSearchPaths,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        workingDirectory: String? = nil,
        defaultTimeout: TimeInterval? = nil,
        defaultOutputLimit: Int = 10_485_760
    )

    public let executor: any CommandExecutor
    public let searchPaths: [String]
    public let environment: [String: String]
    public let workingDirectory: String?
    public let defaultTimeout: TimeInterval?
    public let defaultOutputLimit: Int
}
```

#### Command

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

#### Pipeline

```swift
public struct Pipeline: Sendable {
    public let stages: [Command]

    public func pipe(to next: Command) -> Self
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput
}
```

#### OutputDestination

```swift
public enum OutputDestination: Sendable {
    case capture
    case discard
    case file(path: String, append: Bool)
}
```

#### ShellOutput

```swift
public struct ShellOutput: Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32
    public var isSuccess: Bool
}
```

#### ShellError

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

public enum StreamKind: Sendable {
    case stdout
    case stderr
}
```

#### Workflow\<Value\>

```swift
public struct Workflow<Value>: Sendable {
    public consuming func run() async throws -> Value

    public func map<T>(_ transform: @escaping @Sendable (Value) throws -> T) -> Workflow<T>
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

Workflows are **single-use**. Call `run()` exactly once. Rebuild from the source client to repeat.

#### Git / GitStatusWorkflow

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

public struct GitStatusWorkflow: Sendable {
    public consuming func run() async throws -> GitStatus

    public func map<T>(_ transform: @escaping @Sendable (GitStatus) throws -> T) -> Workflow<T>
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

#### Grep

```swift
public struct Grep: Sendable {
    public init(_ pattern: String, context: ShellContext = .init())       // literal
    public static func regex(_ pattern: String, context: ShellContext = .init()) -> Self

    // standard fluent overrides...
    public func ignoreCase(_ enabled: Bool = true) -> Self
    public func invertMatch(_ enabled: Bool = true) -> Self
    public func lineNumbers(_ enabled: Bool = true) -> Self
    public func file(_ path: String) -> Self
    public func files(_ paths: [String]) -> Self

    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

#### XcodeBuild

```swift
public struct XcodeBuild: Sendable {
    public init(context: ShellContext = .init())

    // standard fluent overrides...
    public func option(_ option: XcodeBuildOption) -> Self
    public func options(_ values: [XcodeBuildOption]) -> Self
    public func trailingArgument(_ value: String) -> Self
    public func trailingArguments(_ values: [String]) -> Self
    public func buildSetting(_ name: String, _ value: String) -> Self
    public func buildSettings(_ values: KeyValuePairs<String, String>) -> Self

    public func command() -> Command
    public func run() async throws -> ShellOutput
}
```

Key `XcodeBuildOption` builders: `.workspace(_:)`, `.scheme(_:)`, `.destination(_:)`, `.sdk(_:)`, `.configuration(_:)`, `.arch(_:)`, `.derivedDataPath(_:)`.

#### Xcrun / Simctl

```swift
public struct Xcrun: Sendable {
    public init(context: ShellContext = .init())
    // standard fluent overrides...
    public func option(_ option: XcrunOption) -> Self
    public func tool(_ value: String) -> Self
    public func trailingArguments(_ values: [String]) -> Self
    public func simctl() -> Simctl
    public func command() -> Command
    public func run() async throws -> ShellOutput
}

public struct Simctl: Sendable {
    public func list(_ target: SimctlListTarget? = nil, json: Bool = false, searchTerm: String? = nil) -> Self
    public func boot(_ device: String) -> Self
    public func shutdown(_ devices: [String]) -> Self
    public func erase(_ devices: [String]) -> Self
    public func install(_ device: String, appAt path: String) -> Self
    public func launch(_ device: String, bundleIdentifier: String) -> Self
    public func custom(_ subcommand: String, arguments: [String] = []) -> Self
    public func builtCommand() -> Command
    public func run() async throws -> ShellOutput
}
```

#### MockExecutor (for testing)

```swift
public struct MockExecutor: CommandExecutor {
    public typealias Handler = @Sendable (Command, ShellContext) async throws -> ShellOutput

    public init(handler: @escaping Handler)
    public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0)
}
```

### Code Generation Rules

1. Always `import SwiftyShell`
2. All `run()` calls are `async throws` — the caller must be in an `async` context
3. Never construct raw shell strings as the primary execution model
4. Prefer `Git` when the operation is covered by the typed git API; otherwise use `Command("git", ...)`
5. Prefer key-path `require` over closure `require` when checking a single property equality
6. Prefer `async let` / `TaskGroup` for concurrent runs — do not serialize what can run in parallel
7. Always pass an explicit `ShellContext` rather than relying on the default `.init()`
8. Workflows are single-use — rebuild from the source client to repeat
9. Use `MockExecutor` in tests — never spawn real processes in unit tests
10. **Every `public` declaration you write must have a `///` doc comment** — see Part 2 for documentation rules

### Worked Examples

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

// Git status check then pull (key-path require)
try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Git status with closure condition
try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require({ !$0.hasUnstagedChanges }, else: MyError.dirtyTree)
    .fetch()
    .run()

// Concurrent git fetch
let git = Git(context: context)
try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
    for path in repoPaths {
        group.addTask { try await git.workingDirectory(path).fetch().run() }
    }
    for try await _ in group {}
}

// Environment override
try await Command("ruby", "deploy.rb")
    .env("RAILS_ENV", "production")
    .run(in: context)

// XcodeBuild
let output = try await XcodeBuild(context: context)
    .option(.workspace("MyApp.xcworkspace"))
    .option(.scheme("MyApp"))
    .option(.destination("platform=iOS Simulator,name=iPhone 17"))
    .trailingArgument("build")
    .run()

// MockExecutor in tests
let context = ShellContext(executor: MockExecutor(stdout: "main\n"))
let status = try await Git(context: context).status().run()
```

### Error Handling Reference

| Case | Cause | Typical response |
|---|---|---|
| `commandNotFound` | Executable not on search path | Check `ShellContext.searchPaths` or use `.executable(_:)` |
| `exitFailure` | Non-zero exit code | Inspect `output.stderr`; retry or abort |
| `timeout` | Command exceeded time limit | Inspect `partialOutput`, increase timeout |
| `outputLimitExceeded` | Output exceeded configured limit | Raise `outputLimit(_:)` or redirect to file |
| `decodingError` | Output is not valid UTF-8 | Redirect output to file and read as `Data` |
| `cancelled` | Parent Swift task was cancelled | Inspect `partialOutput`, propagate cancellation |
| `workflowConditionFailed` | A `require` predicate returned false | Handle the specific workflow gate |
| `spawnError` | Process could not be launched | Check executable path and permissions |

---

## Part 2: Documentation Requirements — MANDATORY

**Every public declaration must have a `///` doc comment. This is a hard requirement, not a suggestion.**

### What Requires a Doc Comment

- `public struct`, `public class`, `public enum`, `public protocol`
- `public var`, `public let` (properties and stored state)
- `public func`, `public init`
- `public typealias`
- `public case` on enums

### Documentation Rules

1. **Type-level docs** — explain what the type _is_ and when to use it; include a short code example for primary API types
2. **Method-level docs** — explain what the method _does_; call out any non-obvious side effects or semantics
3. **Parameter docs** — use `- Parameter name:` for non-trivial parameters; `- Returns:` when the return value isn't obvious; `- Throws:` listing the `ShellError` cases that can be thrown
4. **Cross-references** — use ``SymbolName`` double-backtick syntax to link related types
5. **Examples** — include `///` code fences (` ``` swift `) in type-level docs for all public-facing types

### Verification Step

After writing or modifying any Swift file, scan every line that starts with `public ` and confirm it is immediately preceded (allowing for `@` attributes and blank lines) by a `///` doc comment. If any are missing, add them before finishing.

### Example of Correct Documentation

```swift
/// A typed entry point for running `git` commands with structured results.
///
/// ```swift
/// let status = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .run()
/// ```
public struct Git: ToolConfigurableCommandFamily {

    /// Returns a workflow that queries the current working-tree status.
    ///
    /// - Returns: A ``GitStatusWorkflow`` that produces a ``GitStatus`` on success.
    public func status() -> GitStatusWorkflow { ... }

    /// Pulls the current branch from its upstream remote.
    ///
    /// - Returns: A ``Workflow`` that produces a ``GitPullResult``.
    /// - Throws: ``ShellError/exitFailure(_:_:)`` when the pull fails (e.g. merge conflict,
    ///   unreachable remote).
    public func pull() -> Workflow<GitPullResult> { ... }
}
```

---

## Part 3: Authoring New Command Families

Use this section when adding or revising command families.

### Goals

- Preserve SwiftyShell's fluent, immutable value-type API style
- Keep command family state private; derive shell arguments only in `command()`
- Make it easy for other contributors to add new command wrappers consistently

### Authoring Rules

1. New command families must be value types (`struct`) and `Sendable`
2. Do not expose stored configuration as public properties unless it is part of the intended API surface
3. Store state privately; use non-`mutating` fluent methods that return a new value
4. If the command supports tool config overrides, conform to `ToolConfigurableCommandFamily`
5. If the command supports stdout/stderr redirection, conform to `OutputRedirectingCommandFamily`
6. If the command can materialize a `Command`, conform to `RunnableCommandFamily`
7. Build argv in exactly one place: `command()`
8. Prefer semantic methods like `.source(_:)`, `.destination(_:)` over raw option strings
9. Add tests for both command building and real execution where practical
10. **Every `public` declaration must have a `///` doc comment** — apply documentation rules from Part 2

### Recommended Structure

```swift
import Foundation

public struct ExampleTool: RunnableCommandFamily {
    private let state: State

    public var context: ShellContext { state.config.context }

    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        with(config: update(state.config))
    }

    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        with(stdoutDestination: destination)
    }

    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        with(stderrDestination: destination)
    }

    public func verbose(_ enabled: Bool = true) -> Self {
        with(isVerbose: enabled)
    }

    public func file(_ path: String) -> Self {
        with(files: state.files + [path])
    }

    public func command() -> Command {
        var arguments: [String] = []
        if state.isVerbose { arguments.append("--verbose") }
        arguments.append(contentsOf: state.files)

        let base = Command("example-tool")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func with(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isVerbose: Bool? = nil,
        files: [String]? = nil
    ) -> Self {
        Self(state: State(
            config: config ?? state.config,
            stdoutDestination: stdoutDestination ?? state.stdoutDestination,
            stderrDestination: stderrDestination ?? state.stderrDestination,
            isVerbose: isVerbose ?? state.isVerbose,
            files: files ?? state.files
        ))
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isVerbose: Bool
    let files: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isVerbose: Bool = false,
        files: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isVerbose = isVerbose
        self.files = files
    }
}
```

### Test Checklist

For every new command family:

- Builder test that checks `command().arguments`
- At least one execution test if the tool is expected in the environment
- If the tool may be missing, gate the execution test safely
- MockExecutor-based unit tests for typed workflow clients

---

## Skill Maintenance

Update this file in the same PR as any public API change:
- New typed client or method added
- Method signature changed
- `ShellError` cases added or renamed
- Execution semantics changed (pipeline exit, environment merging, etc.)
- New reusable command-family protocol introduced

The skill must reflect the implemented API, not the spec.

## Documentation Checklist

Before submitting any change to this codebase, verify:

- [ ] Every `public` type, property, method, init, and enum case has a `///` doc comment
- [ ] Type-level docs include a code example for primary API surface types
- [ ] Non-trivial parameters have `- Parameter name:` documentation
- [ ] Methods that throw list the `ShellError` cases they can throw with `- Throws:`
- [ ] Cross-references use ``SymbolName`` double-backtick syntax
- [ ] The skill file (`.claude/skills/swiftyshell.md`) is updated if public API changed
