#if Ln
import Foundation

/// A typed wrapper for creating one hard or symbolic link with `ln`.
///
/// ```swift
/// try await Ln(source: "current", destination: "latest")
///     .symbolic()
///     .run()
/// ```
public struct Ln: RunnableCommandFamily {
    private let state: State

    /// The shell context used to execute the command.
    public var context: ShellContext { state.config.context }

    /// Creates an `ln` command with its required source and destination operands.
    ///
    /// - Parameters:
    ///   - source: The existing file, or the target text for a symbolic link.
    ///   - destination: The path at which to create the link.
    ///   - context: The shell context used to execute the command.
    public init(source: String, destination: String, context: ShellContext = .init()) {
        self.state = State(
            config: ToolConfiguration(context: context),
            source: source,
            destination: destination
        )
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

    /// Returns a copy that creates a symbolic link instead of a hard link.
    ///
    /// - Parameter enabled: Whether to pass the portable `-s` option.
    public func symbolic(_ enabled: Bool = true) -> Self {
        copy(isSymbolic: enabled)
    }

    /// Returns a copy that removes an existing destination before creating the link.
    ///
    /// - Parameter enabled: Whether to pass the portable `-f` option.
    public func force(_ enabled: Bool = true) -> Self {
        copy(forcesReplacement: enabled)
    }

    /// Builds the configured `ln` command.
    public func command() -> Command {
        var arguments: [String] = []
        if state.isSymbolic { arguments.append("-s") }
        if state.forcesReplacement { arguments.append("-f") }
        arguments.append(contentsOf: [state.source, state.destination])

        return state.config.apply(
            to: Command("ln")
                .args(arguments)
                .stdout(state.stdoutDestination)
                .stderr(state.stderrDestination)
        )
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isSymbolic: Bool? = nil,
        forcesReplacement: Bool? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                source: state.source,
                destination: state.destination,
                isSymbolic: isSymbolic ?? state.isSymbolic,
                forcesReplacement: forcesReplacement ?? state.forcesReplacement
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let source: String
    let destination: String
    let isSymbolic: Bool
    let forcesReplacement: Bool

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        source: String,
        destination: String,
        isSymbolic: Bool = false,
        forcesReplacement: Bool = false
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.source = source
        self.destination = destination
        self.isSymbolic = isSymbolic
        self.forcesReplacement = forcesReplacement
    }
}
#endif
