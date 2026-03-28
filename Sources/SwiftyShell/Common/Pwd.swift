import Foundation

/// A fluent wrapper for the `pwd` command.
public struct Pwd: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `pwd` command family bound to a shell context.
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

    /// Redirects stdout for the built `pwd` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `pwd` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Uses a physical path with symlinks resolved.
    public func physical(_ enabled: Bool = true) -> Self {
        copy(usesPhysicalPath: enabled, usesLogicalPath: enabled ? false : state.usesLogicalPath)
    }

    /// Uses a logical path that preserves symlinks when possible.
    public func logical(_ enabled: Bool = true) -> Self {
        copy(usesPhysicalPath: enabled ? false : state.usesPhysicalPath, usesLogicalPath: enabled)
    }

    /// Builds the raw `pwd` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.usesPhysicalPath {
            arguments.append("-P")
        }
        if state.usesLogicalPath {
            arguments.append("-L")
        }

        let base = Command("pwd")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        usesPhysicalPath: Bool? = nil,
        usesLogicalPath: Bool? = nil
    ) -> Self {
        Self(state: State(
            config: config ?? state.config,
            stdoutDestination: stdoutDestination ?? state.stdoutDestination,
            stderrDestination: stderrDestination ?? state.stderrDestination,
            usesPhysicalPath: usesPhysicalPath ?? state.usesPhysicalPath,
            usesLogicalPath: usesLogicalPath ?? state.usesLogicalPath
        ))
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let usesPhysicalPath: Bool
    let usesLogicalPath: Bool

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        usesPhysicalPath: Bool = false,
        usesLogicalPath: Bool = false
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.usesPhysicalPath = usesPhysicalPath
        self.usesLogicalPath = usesLogicalPath
    }
}
