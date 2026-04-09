# Building Custom Command Families

Create a strongly-typed wrapper for any command-line tool following SwiftyShell conventions.

## Overview

SwiftyShell provides three protocol tiers for typed command families:

| Protocol | What it adds |
|---|---|
| ``ToolConfigurableCommandFamily`` | `executable`, `env`, `workingDirectory`, `timeout`, `outputLimit` |
| ``OutputRedirectingCommandFamily`` | `stdout`, `stderr` |
| ``RunnableCommandFamily`` | `command()`, `run()` |

Most tools should conform to ``RunnableCommandFamily``, which inherits all three tiers.

## Recommended Structure

The canonical pattern uses a private `State` struct to hold all configuration
and a private `copy(...)` helper for fluent updates. Public state that is part
of the API surface can be exposed via computed properties.

```swift
import Foundation
import SwiftyShell

/// A fluent wrapper for the `my-tool` command.
///
/// ```swift
/// let output = try await MyTool(context: context)
///     .verbose()
///     .inputFile("data.json")
///     .run()
/// ```
public struct MyTool: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `my-tool` command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Redirects stdout for the built command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    // MARK: - Tool-specific options

    /// Enables verbose output.
    public func verbose(_ enabled: Bool = true) -> Self {
        copy(isVerbose: enabled)
    }

    /// Appends an input file path.
    public func inputFile(_ path: String) -> Self {
        copy(inputFiles: state.inputFiles + [path])
    }

    // MARK: - Command building

    /// Builds the raw ``Command`` represented by the current configuration.
    public func command() -> Command {
        var arguments: [String] = []
        if state.isVerbose { arguments.append("--verbose") }
        arguments.append(contentsOf: state.inputFiles)

        let base = Command("my-tool")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isVerbose: Bool? = nil,
        inputFiles: [String]? = nil
    ) -> Self {
        Self(state: State(
            config: config ?? state.config,
            stdoutDestination: stdoutDestination ?? state.stdoutDestination,
            stderrDestination: stderrDestination ?? state.stderrDestination,
            isVerbose: isVerbose ?? state.isVerbose,
            inputFiles: inputFiles ?? state.inputFiles
        ))
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isVerbose: Bool
    let inputFiles: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isVerbose: Bool = false,
        inputFiles: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isVerbose = isVerbose
        self.inputFiles = inputFiles
    }
}
```

## Key Rules

- **Value type, `Sendable`**: every command family is a `struct` that conforms to `Sendable`.
- **Immutable state**: fluent methods return a new copy — never mutate `self`.
- **Single build site**: assemble all `argv` arguments in exactly one place: `command()`.
- **Apply tool config last**: call `state.config.apply(to: base)` at the end of `command()`.
- **Doc comments everywhere**: every `public` declaration requires a `///` doc comment.

## Conforming Without `RunnableCommandFamily`

If your type only needs configuration overrides but should not be directly runnable
(for example, a sub-client that returns structured results), conform to
``ToolConfigurableCommandFamily`` instead:

```swift
public struct MyWorkflowClient: ToolConfigurableCommandFamily {
    public let config: ToolConfiguration
    public var context: ShellContext { config.context }

    public init(context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
    }

    private init(config: ToolConfiguration) { self.config = config }

    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        Self(config: update(config))
    }

    /// Builds a workflow that processes data.
    public func process(_ input: String) -> Workflow<String> {
        Workflow {
            let output = try await Command("my-tool", input).run(in: self.context)
            return output.stdout
        }
    }
}
```

## Adding Tests

For every new command family, add:

1. **Builder test** — verify `command().arguments` without spawning a process:

```swift
@Test func myToolBuildsCommand() {
    let cmd = MyTool()
        .verbose()
        .inputFile("data.json")
        .command()

    #expect(cmd.arguments == ["--verbose", "data.json"])
}
```

2. **Mock execution test** — verify the caller handles output correctly:

```swift
@Test func myToolParsesOutput() async throws {
    let mock = MockExecutor(stdout: "processed: 42 items\n")
    let context = ShellContext(executor: mock)
    let output = try await MyTool(context: context).inputFile("data.json").run()
    #expect(output.stdout.contains("42"))
}
```

3. **Real execution test** — guarded to skip gracefully when the tool is absent:

```swift
@Test func myToolRealExecution() async throws {
    guard (try? await Command("my-tool", "--version").run(in: .init()))?.isSuccess == true else {
        return
    }
    let output = try await MyTool().inputFile("fixtures/sample.json").run()
    #expect(output.isSuccess)
}
```
