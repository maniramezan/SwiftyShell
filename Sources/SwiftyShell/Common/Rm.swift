#if Rm
import Foundation

/// A fluent wrapper for the `rm` command.
///
/// Use ``Rm`` to remove files or directories. Successful removals usually produce no output;
/// failures throw ``ShellError/exitFailure(command:output:)-enum.case`` with the `rm` diagnostic text in
/// `stderr`.
///
/// ```swift
/// try await Rm(context: context)
///     .recursive()    // Remove directory contents.
///     .force()        // Do not fail for missing paths.
///     .path("/tmp/build")
///     .run()
/// ```
public struct Rm: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an `rm` command family bound to a shell context.
    ///
    /// All builder state starts empty: no paths, no flags. Configure with the fluent helpers
    /// before calling ``run()`` or ``command()``.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Rm`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `rm` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `rm` typically produces no stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Rm`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `rm` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `rm` writes diagnostic messages here when a
    /// path cannot be removed.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Rm`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that removes directories recursively.
    ///
    /// Maps to the `-r` flag. Required to remove directories — without it, `rm` refuses to
    /// recurse into directory paths and exits non-zero.
    ///
    /// ```swift
    /// try await Rm(context: context)
    ///     .recursive()
    ///     .path("/tmp/build")
    ///     .run()
    /// ```
    ///
    /// - Parameter enabled: `true` to add `-r`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Rm`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isRecursive = enabled }
    }

    /// Returns a copy that forces removal without prompting and ignores missing paths.
    ///
    /// Maps to the `-f` flag. Particularly useful when removing paths that may or may not
    /// exist; `rm -f` exits successfully when a path is missing rather than failing.
    ///
    /// - Parameter enabled: `true` to add `-f`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Rm`` value with the flag applied.
    public func force(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.forcesRemoval = enabled }
    }

    /// Returns a copy with one additional path appended for removal.
    ///
    /// - Parameter value: The file or directory path to remove.
    /// - Returns: A new ``Rm`` value with the path appended.
    public func path(_ value: String) -> Self {
        modified(self) { $0.state.paths += [value] }
    }

    /// Returns a copy with multiple paths appended for removal.
    ///
    /// - Parameter values: The paths to append, in order.
    /// - Returns: A new ``Rm`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        modified(self) { $0.state.paths += values }
    }

    /// Builds the raw `rm` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: flags, then paths. The shared ``ToolConfiguration``
    /// overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.isRecursive {
            arguments.append("-r")
        }
        if state.forcesRemoval {
            arguments.append("-f")
        }

        if !state.paths.isEmpty { arguments.append("--") }
        arguments.append(contentsOf: state.paths)

        let base = Command("rm")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var isRecursive: Bool = false
    var forcesRemoval: Bool = false
    var paths: [String] = []
}
#endif
