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
    private var state: State

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
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy with the command's stdout destination changed.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy with the command's stderr destination changed.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that creates a symbolic link instead of a hard link.
    ///
    /// - Parameter enabled: Whether to pass the portable `-s` option.
    public func symbolic(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isSymbolic = enabled }
    }

    /// Returns a copy that removes an existing destination before creating the link.
    ///
    /// - Parameter enabled: Whether to pass the portable `-f` option.
    public func force(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.forcesReplacement = enabled }
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
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var source: String
    var destination: String
    var isSymbolic: Bool = false
    var forcesReplacement: Bool = false
}
#endif
