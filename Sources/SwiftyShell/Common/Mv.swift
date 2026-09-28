#if Mv
import Foundation

/// A fluent wrapper for the `mv` command.
///
/// Use ``Mv`` to move or rename files and directories. Successful moves usually produce no output,
/// so completion is the result; multiple sources require the destination to be a directory.
///
/// ```swift
/// try await Mv(context: context)
///     .source("/tmp/output.txt")
///     .destination("/var/logs/output.txt")
///     .run()
/// ```
public struct Mv: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an `mv` command family bound to a shell context.
    ///
    /// All builder state starts empty: no sources, no destination, no flags. Configure with the
    /// fluent helpers before calling ``run()`` or ``command()``.
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
    /// - Returns: A new ``Mv`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `mv` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `mv` typically produces no stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Mv`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `mv` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `mv` writes diagnostic messages here when
    /// permission is denied or sources do not exist.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Mv`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that forces replacement of existing destinations.
    ///
    /// Maps to the `-f` flag. With this enabled, `mv` overwrites the destination without
    /// prompting and without confirming on read-only files.
    ///
    /// - Parameter enabled: `true` to add `-f`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Mv`` value with the flag applied.
    public func force(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.forcesReplacement = enabled }
    }

    /// Returns a copy with one additional source path appended.
    ///
    /// Sources are forwarded to `mv` in declaration order, before the destination. When more
    /// than one source is supplied, the destination must be a directory.
    ///
    /// - Parameter path: A file or directory path to move.
    /// - Returns: A new ``Mv`` value with the source appended.
    public func source(_ path: String) -> Self {
        modified(self) { $0.state.sources += [path] }
    }

    /// Returns a copy with multiple source paths appended.
    ///
    /// - Parameter paths: The source paths to append, in order.
    /// - Returns: A new ``Mv`` value with the sources appended.
    public func sources(_ paths: [String]) -> Self {
        modified(self) { $0.state.sources += paths }
    }

    /// Returns a copy that uses `path` as the destination of the move.
    ///
    /// May be a file path (when renaming a single file) or a directory path (when moving one or
    /// more sources into it). Calling this multiple times keeps the last value.
    ///
    /// - Parameter path: The destination path.
    /// - Returns: A new ``Mv`` value with the destination set.
    public func destination(_ path: String) -> Self {
        modified(self) { $0.state.destinationPath = path }
    }

    /// Builds the raw `mv` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: flags, then sources, then destination. The shared
    /// ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.forcesReplacement {
            arguments.append("-f")
        }

        if !state.sources.isEmpty || state.destinationPath != nil { arguments.append("--") }
        arguments.append(contentsOf: state.sources)

        if let destinationPath = state.destinationPath {
            arguments.append(destinationPath)
        }

        let base = Command("mv")
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
    var forcesReplacement: Bool = false
    var sources: [String] = []
    var destinationPath: String? = nil
}
#endif
