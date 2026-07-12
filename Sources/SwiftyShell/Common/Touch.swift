#if Touch
import Foundation

/// A typed wrapper for updating timestamps or creating files with `touch`.
///
/// ```swift
/// try await Touch("build.stamp").run()
/// ```
public struct Touch: RunnableCommandFamily {
    private let state: State

    /// The shell context used to execute the command.
    public var context: ShellContext { state.config.context }

    /// Creates a `touch` command with its first required path operand.
    ///
    /// - Parameters:
    ///   - path: A file whose timestamps should be changed, creating it when absent by default.
    ///   - context: The shell context used to execute the command.
    public init(_ path: String, context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context), paths: [path])
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy with the command's stdout destination changed.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy with the command's stderr destination changed.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that changes only access times.
    ///
    /// - Parameter enabled: Whether to pass the portable `-a` option.
    public func accessTimeOnly(_ enabled: Bool = true) -> Self {
        copy(accessTimeOnly: enabled)
    }

    /// Returns a copy that changes only modification times.
    ///
    /// - Parameter enabled: Whether to pass the portable `-m` option.
    public func modificationTimeOnly(_ enabled: Bool = true) -> Self {
        copy(modificationTimeOnly: enabled)
    }

    /// Returns a copy that does not create paths that are absent.
    ///
    /// - Parameter enabled: Whether to pass the portable `-c` option.
    public func noCreate(_ enabled: Bool = true) -> Self {
        copy(doesNotCreate: enabled)
    }

    /// Returns a copy that copies timestamps from a reference file.
    ///
    /// - Parameter path: The file whose access and modification times should be used.
    public func reference(_ path: String) -> Self {
        copy(referencePath: path, timestamp: .some(nil))
    }

    /// Returns a copy with a portable `[[CC]YY]MMDDhhmm[.SS]` timestamp.
    ///
    /// - Parameter value: The timestamp text passed unchanged to `touch -t`.
    public func timestamp(_ value: String) -> Self {
        copy(referencePath: .some(nil), timestamp: value)
    }

    /// Returns a copy with another file path appended.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Returns a copy with multiple file paths appended.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the configured `touch` command.
    public func command() -> Command {
        var arguments: [String] = []
        if state.accessTimeOnly { arguments.append("-a") }
        if state.modificationTimeOnly { arguments.append("-m") }
        if state.doesNotCreate { arguments.append("-c") }
        if let referencePath = state.referencePath { arguments.append(contentsOf: ["-r", referencePath]) }
        if let timestamp = state.timestamp { arguments.append(contentsOf: ["-t", timestamp]) }
        arguments.append(contentsOf: state.paths)

        return state.config.apply(
            to: Command("touch")
                .args(arguments)
                .stdout(state.stdoutDestination)
                .stderr(state.stderrDestination)
        )
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        accessTimeOnly: Bool? = nil,
        modificationTimeOnly: Bool? = nil,
        doesNotCreate: Bool? = nil,
        referencePath: String?? = nil,
        timestamp: String?? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                paths: paths ?? state.paths,
                accessTimeOnly: accessTimeOnly ?? state.accessTimeOnly,
                modificationTimeOnly: modificationTimeOnly ?? state.modificationTimeOnly,
                doesNotCreate: doesNotCreate ?? state.doesNotCreate,
                referencePath: referencePath ?? state.referencePath,
                timestamp: timestamp ?? state.timestamp
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let paths: [String]
    let accessTimeOnly: Bool
    let modificationTimeOnly: Bool
    let doesNotCreate: Bool
    let referencePath: String?
    let timestamp: String?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        paths: [String],
        accessTimeOnly: Bool = false,
        modificationTimeOnly: Bool = false,
        doesNotCreate: Bool = false,
        referencePath: String? = nil,
        timestamp: String? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.paths = paths
        self.accessTimeOnly = accessTimeOnly
        self.modificationTimeOnly = modificationTimeOnly
        self.doesNotCreate = doesNotCreate
        self.referencePath = referencePath
        self.timestamp = timestamp
    }
}
#endif
