import Foundation

/// A named string argument passed to `jq` via `--arg`.
public struct JqArgument: Sendable, Equatable, Hashable {
    /// The jq variable name.
    public let name: String
    /// The string value assigned to the variable.
    public let value: String

    /// Creates a `jq` string argument.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    fileprivate var arguments: [String] {
        ["--arg", name, value]
    }
}

/// A fluent wrapper for the `jq` command.
///
/// ``Jq`` supports raw-string output, compact output, key sorting, null input,
/// slurp mode, and `--arg` string bindings:
///
/// ```swift
/// // Extract a field as raw text
/// let output = try await Jq(".name", context: context)
///     .rawOutput()
///     .file("package.json")
///     .run()
/// let name = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
///
/// // Pass a variable into the filter
/// let result = try await Jq(".items[] | select(.id == $id)", context: context)
///     .arg("id", "abc123")
///     .file("data.json")
///     .run()
/// ```
public struct Jq: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `jq` command family with an optional filter expression.
    public init(_ filter: String = ".", context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context), filterExpression: filter)
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

    /// Redirects stdout for the built `jq` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `jq` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Replaces the jq filter expression.
    public func filter(_ value: String) -> Self {
        copy(filterExpression: value)
    }

    /// Emits raw strings instead of JSON-encoded output.
    public func rawOutput(_ enabled: Bool = true) -> Self {
        copy(emitsRawStrings: enabled)
    }

    /// Emits compact JSON output.
    public func compactOutput(_ enabled: Bool = true) -> Self {
        copy(emitsCompactOutput: enabled)
    }

    /// Slurps the input stream into a single array value.
    public func slurp(_ enabled: Bool = true) -> Self {
        copy(slurpsInput: enabled)
    }

    /// Runs jq with null input.
    public func nullInput(_ enabled: Bool = true) -> Self {
        copy(usesNullInput: enabled)
    }

    /// Sorts object keys in the output.
    public func sortKeys(_ enabled: Bool = true) -> Self {
        copy(sortsKeys: enabled)
    }

    /// Adds a `--arg` string binding.
    public func arg(_ name: String, _ value: String) -> Self {
        copy(stringArguments: state.stringArguments + [JqArgument(name: name, value: value)])
    }

    /// Appends an input file path.
    public func file(_ path: String) -> Self {
        copy(filePaths: state.filePaths + [path])
    }

    /// Appends multiple input file paths.
    public func files(_ paths: [String]) -> Self {
        copy(filePaths: state.filePaths + paths)
    }

    /// Builds the raw `jq` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.emitsRawStrings {
            arguments.append("-r")
        }
        if state.emitsCompactOutput {
            arguments.append("-c")
        }
        if state.slurpsInput {
            arguments.append("-s")
        }
        if state.usesNullInput {
            arguments.append("-n")
        }
        if state.sortsKeys {
            arguments.append("-S")
        }

        arguments.append(contentsOf: state.stringArguments.flatMap(\.arguments))
        arguments.append(state.filterExpression)
        arguments.append(contentsOf: state.filePaths)

        let base = Command("jq")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        filterExpression: String? = nil,
        emitsRawStrings: Bool? = nil,
        emitsCompactOutput: Bool? = nil,
        slurpsInput: Bool? = nil,
        usesNullInput: Bool? = nil,
        sortsKeys: Bool? = nil,
        stringArguments: [JqArgument]? = nil,
        filePaths: [String]? = nil
    ) -> Self {
        Self(state: State(
            config: config ?? state.config,
            stdoutDestination: stdoutDestination ?? state.stdoutDestination,
            stderrDestination: stderrDestination ?? state.stderrDestination,
            filterExpression: filterExpression ?? state.filterExpression,
            emitsRawStrings: emitsRawStrings ?? state.emitsRawStrings,
            emitsCompactOutput: emitsCompactOutput ?? state.emitsCompactOutput,
            slurpsInput: slurpsInput ?? state.slurpsInput,
            usesNullInput: usesNullInput ?? state.usesNullInput,
            sortsKeys: sortsKeys ?? state.sortsKeys,
            stringArguments: stringArguments ?? state.stringArguments,
            filePaths: filePaths ?? state.filePaths
        ))
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let filterExpression: String
    let emitsRawStrings: Bool
    let emitsCompactOutput: Bool
    let slurpsInput: Bool
    let usesNullInput: Bool
    let sortsKeys: Bool
    let stringArguments: [JqArgument]
    let filePaths: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        filterExpression: String = ".",
        emitsRawStrings: Bool = false,
        emitsCompactOutput: Bool = false,
        slurpsInput: Bool = false,
        usesNullInput: Bool = false,
        sortsKeys: Bool = false,
        stringArguments: [JqArgument] = [],
        filePaths: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.filterExpression = filterExpression
        self.emitsRawStrings = emitsRawStrings
        self.emitsCompactOutput = emitsCompactOutput
        self.slurpsInput = slurpsInput
        self.usesNullInput = usesNullInput
        self.sortsKeys = sortsKeys
        self.stringArguments = stringArguments
        self.filePaths = filePaths
    }
}
