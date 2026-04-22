import Foundation

/// A fluent wrapper for the `mkdir` command.
///
/// ```swift
/// // Create a nested directory tree
/// try await Mkdir(context: context)
///     .parents()
///     .directory("/tmp/output/logs")
///     .run()
/// ```
public struct Mkdir: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `mkdir` command family bound to a shell context.
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

    /// Redirects stdout for the built `mkdir` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `mkdir` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Creates intermediate directories as needed.
    public func parents(_ enabled: Bool = true) -> Self {
        copy(createsIntermediateDirectories: enabled)
    }

    /// Sets the mode passed to `mkdir -m`.
    public func mode(_ value: String) -> Self {
        copy(modeValue: value)
    }

    /// Appends a directory path to create.
    public func directory(_ path: String) -> Self {
        copy(directories: state.directories + [path])
    }

    /// Appends multiple directory paths to create.
    public func directories(_ paths: [String]) -> Self {
        copy(directories: state.directories + paths)
    }

    /// Builds the raw `mkdir` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.createsIntermediateDirectories {
            arguments.append("-p")
        }
        if let modeValue = state.modeValue {
            arguments.append(contentsOf: ["-m", modeValue])
        }

        arguments.append(contentsOf: state.directories)

        let base = Command("mkdir")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        createsIntermediateDirectories: Bool? = nil,
        modeValue: String?? = nil,
        directories: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                createsIntermediateDirectories: createsIntermediateDirectories ?? state.createsIntermediateDirectories,
                modeValue: modeValue ?? state.modeValue,
                directories: directories ?? state.directories
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let createsIntermediateDirectories: Bool
    let modeValue: String?
    let directories: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        createsIntermediateDirectories: Bool = false,
        modeValue: String? = nil,
        directories: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.createsIntermediateDirectories = createsIntermediateDirectories
        self.modeValue = modeValue
        self.directories = directories
    }
}
