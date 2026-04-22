import Foundation

/// A fluent wrapper for the `rm` command.
///
/// ```swift
/// // Remove a directory and its contents
/// try await Rm(context: context)
///     .recursive()
///     .force()
///     .path("/tmp/build")
///     .run()
/// ```
public struct Rm: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates an `rm` command family bound to a shell context.
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

    /// Redirects stdout for the built `rm` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `rm` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Removes directories recursively.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Forces removal without prompting.
    public func force(_ enabled: Bool = true) -> Self {
        copy(forcesRemoval: enabled)
    }

    /// Appends a path to remove.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Appends multiple paths to remove.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `rm` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.isRecursive {
            arguments.append("-r")
        }
        if state.forcesRemoval {
            arguments.append("-f")
        }

        arguments.append(contentsOf: state.paths)

        let base = Command("rm")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isRecursive: Bool? = nil,
        forcesRemoval: Bool? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                isRecursive: isRecursive ?? state.isRecursive,
                forcesRemoval: forcesRemoval ?? state.forcesRemoval,
                paths: paths ?? state.paths
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isRecursive: Bool
    let forcesRemoval: Bool
    let paths: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isRecursive: Bool = false,
        forcesRemoval: Bool = false,
        paths: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isRecursive = isRecursive
        self.forcesRemoval = forcesRemoval
        self.paths = paths
    }
}
