#if Jq
import Foundation

/// A named string argument passed to `jq` via `--arg`.
///
/// Wraps a `name` / `value` pair so the value is bound to a jq variable (`$name`) rather than
/// being interpolated into the filter string. This avoids quoting headaches and prevents jq
/// program injection when the value comes from user input.
public struct JqArgument: Sendable, Equatable, Hashable {
    /// The jq variable name (without the leading `$`).
    public let name: String

    /// The string value bound to the jq variable.
    public let value: String

    /// Creates a `jq` `--arg` binding.
    ///
    /// - Parameters:
    ///   - name: The jq variable name. Inside the filter, refer to it as `$name`.
    ///   - value: The string value to bind. jq treats this as a string regardless of contents;
    ///     use `--argjson` (not yet exposed) for parsed JSON values.
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
/// Use ``rawOutput(_:)`` when a filter returns a string that should be consumed as plain text
/// instead of JSON. The first example returns the `.name` field from `package.json` in
/// ``ShellOutput/stdout``.
///
/// ```swift
/// let output = try await Jq(".name", context: context)
///     .rawOutput()    // Emit the string value directly, without JSON quotes.
///     .file("package.json")
///     .run()
///
/// let name = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
/// ```
///
/// Pass Swift values into filters with ``arg(_:_:)`` rather than interpolating into the jq program
/// string. This keeps the filter stable while changing the selected id.
///
/// ```swift
/// let result = try await Jq(".items[] | select(.id == $id)", context: context)
///     .arg("id", "abc123")
///     .file("data.json")
///     .run()
/// ```
public struct Jq: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `jq` command family with an optional filter expression.
    ///
    /// The filter defaults to `"."`, which echoes the input unchanged. Set explicit input
    /// sources with ``file(_:)`` and ``files(_:)`` (otherwise jq reads from stdin, which only
    /// works inside a pipeline).
    ///
    /// - Parameters:
    ///   - filter: The jq filter expression. Defaults to `"."` (identity).
    ///   - context: The shell context whose executor, search paths, environment, and defaults
    ///     will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(_ filter: String = ".", context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context), filterExpression: filter)
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Jq`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `jq` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Stdout carries the filtered JSON (or raw
    /// strings, when ``rawOutput(_:)`` is enabled), so this is the stream most callers will
    /// inspect.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Jq`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `jq` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `jq` writes parse errors and filter errors
    /// here.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Jq`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy with the jq filter expression replaced.
    ///
    /// Replaces the value supplied to ``init(_:context:)`` (or any earlier call to this
    /// method). Calling this multiple times keeps the last value.
    ///
    /// - Parameter value: The new jq filter expression.
    /// - Returns: A new ``Jq`` value with the filter applied.
    public func filter(_ value: String) -> Self {
        copy(filterExpression: value)
    }

    /// Returns a copy that emits raw strings instead of JSON-encoded output.
    ///
    /// Maps to the `-r` flag. When the filter produces a string, the value is written verbatim
    /// (without surrounding double quotes and without escape sequences). Has no effect on
    /// non-string filter results.
    ///
    /// - Parameter enabled: `true` to add `-r`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Jq`` value with the flag applied.
    public func rawOutput(_ enabled: Bool = true) -> Self {
        copy(emitsRawStrings: enabled)
    }

    /// Returns a copy that emits compact JSON output (no extra whitespace).
    ///
    /// Maps to the `-c` flag. Useful for emitting one JSON object per line — for example when
    /// piping into another tool or when minimizing output size.
    ///
    /// - Parameter enabled: `true` to add `-c`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Jq`` value with the flag applied.
    public func compactOutput(_ enabled: Bool = true) -> Self {
        copy(emitsCompactOutput: enabled)
    }

    /// Returns a copy that slurps the input stream into a single array value.
    ///
    /// Maps to the `-s` flag. Use when the input contains multiple JSON values that should be
    /// processed as a single array — for example, line-delimited JSON.
    ///
    /// - Parameter enabled: `true` to add `-s`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Jq`` value with the flag applied.
    public func slurp(_ enabled: Bool = true) -> Self {
        copy(slurpsInput: enabled)
    }

    /// Returns a copy that runs jq with null input rather than reading from stdin or files.
    ///
    /// Maps to the `-n` flag. Use when the filter generates output entirely from `--arg`
    /// bindings or jq built-ins, with no JSON input source.
    ///
    /// - Parameter enabled: `true` to add `-n`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Jq`` value with the flag applied.
    public func nullInput(_ enabled: Bool = true) -> Self {
        copy(usesNullInput: enabled)
    }

    /// Returns a copy that sorts object keys alphabetically in the output.
    ///
    /// Maps to the `-S` flag. Useful for producing deterministic output suitable for diffing
    /// across runs.
    ///
    /// - Parameter enabled: `true` to add `-S`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Jq`` value with the flag applied.
    public func sortKeys(_ enabled: Bool = true) -> Self {
        copy(sortsKeys: enabled)
    }

    /// Returns a copy with one additional `--arg` string binding appended.
    ///
    /// Inside the filter, refer to the binding as `$name`. Multiple `arg(_:_:)` calls accumulate.
    ///
    /// ```swift
    /// let result = try await Jq(".items[] | select(.id == $id)", context: context)
    ///     .arg("id", "abc123")
    ///     .file("data.json")
    ///     .run()
    /// ```
    ///
    /// - Parameters:
    ///   - name: The jq variable name (without the leading `$`).
    ///   - value: The string value to bind.
    /// - Returns: A new ``Jq`` value with the binding appended.
    public func arg(_ name: String, _ value: String) -> Self {
        copy(stringArguments: state.stringArguments + [JqArgument(name: name, value: value)])
    }

    /// Returns a copy with one additional input file path appended.
    ///
    /// Multiple file paths accumulate; jq concatenates the streams in order.
    ///
    /// - Parameter path: The path to a file containing JSON input.
    /// - Returns: A new ``Jq`` value with the file appended.
    public func file(_ path: String) -> Self {
        copy(filePaths: state.filePaths + [path])
    }

    /// Returns a copy with multiple input file paths appended.
    ///
    /// - Parameter paths: The file paths to append, in order.
    /// - Returns: A new ``Jq`` value with the files appended.
    public func files(_ paths: [String]) -> Self {
        copy(filePaths: state.filePaths + paths)
    }

    /// Builds the raw `jq` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: behavior flags (`-r`, `-c`, `-s`, `-n`, `-S`), then any
    /// `--arg name value` triples, then the filter expression, then file paths. The shared
    /// ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
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
        Self(
            state: State(
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
            )
        )
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
#endif
