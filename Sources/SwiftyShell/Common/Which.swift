#if Which
import Foundation

/// The typed result of searching for an executable with ``Which``.
public enum WhichResult: Sendable, Equatable, Hashable {
    /// The command was found at the reported path.
    case found(path: String)

    /// The command was not found on the search path.
    case notFound
}

/// A typed wrapper for locating one executable with `which`.
///
/// Prefer ``lookup()`` over ``run()`` so an absent executable becomes ``WhichResult/notFound``
/// rather than an execution error.
///
/// ```swift
/// let result = try await Which("swift").lookup().run()
/// ```
public struct Which: RunnableCommandFamily {
    private let state: State

    /// The shell context used to execute the command.
    public var context: ShellContext { state.config.context }

    /// Creates a `which` lookup with its required command-name operand.
    ///
    /// - Parameters:
    ///   - name: The executable name to locate.
    ///   - context: The shell context used to execute the lookup.
    public init(_ name: String, context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context), name: name)
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

    /// Builds the configured `which` command.
    public func command() -> Command {
        state.config.apply(
            to: Command("which")
                .arg(state.name)
                .stdout(state.stdoutDestination)
                .stderr(state.stderrDestination)
        )
    }

    /// Returns a workflow that distinguishes a found executable from normal absence.
    ///
    /// Exit status `1`, used by the macOS and common GNU/Linux `which` implementations for an
    /// unsuccessful lookup, maps to ``WhichResult/notFound``. Other failures remain errors.
    public func lookup() -> Workflow<WhichResult> {
        let command = command()
        let context = state.config.context
        return Workflow {
            do {
                let output = try await command.run(in: context)
                let path = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                return path.isEmpty ? .notFound : .found(path: path)
            } catch let ShellError.exitFailure(_, output) where output.exitCode == 1 {
                return .notFound
            }
        }
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                name: state.name
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let name: String

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        name: String
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.name = name
    }
}
#endif
