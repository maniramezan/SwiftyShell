#if Cp
import Foundation

/// A fluent wrapper for the `cp` command.
///
/// Use ``Cp`` to copy files or directories with a typed builder. Successful copies usually produce
/// no output, so completion without ``ShellError/exitFailure(command:output:)`` is the important
/// result.
///
/// ```swift
/// try await Cp(context: context)
///     .recursive()    // Required when the source is a directory.
///     .source("/path/to/source")
///     .destination("/path/to/dest")
///     .run()
/// ```
public struct Cp: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `cp` command family bound to a shell context.
    ///
    /// All builder state starts empty: no sources, no destination, no flags. Configure further
    /// with the fluent helpers before calling ``run()`` or ``command()``.
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
    /// This is the funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``). Most callers use those
    /// helpers and never invoke this directly.
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Cp`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `cp` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `cp` typically produces no stdout, so this
    /// override is mostly useful when chaining into a pipeline or discarding noise.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Cp`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `cp` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `cp` writes diagnostic messages here when
    /// permission is denied or sources are missing.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Cp`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that enables or disables recursive copying.
    ///
    /// Maps to the `-R` flag. Required when any source is a directory; without it, `cp` refuses
    /// to copy directories and exits with a non-zero status.
    ///
    /// ```swift
    /// try await Cp(context: context)
    ///     .recursive()
    ///     .source("/tmp/build")
    ///     .destination("/var/artifacts")
    ///     .run()
    /// ```
    ///
    /// - Parameter enabled: `true` to add `-R`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Cp`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Returns a copy that forces replacement of existing destinations.
    ///
    /// Maps to the `-f` flag. Without this, `cp` may refuse to overwrite read-only files; with
    /// it, the destination is removed and recreated when needed.
    ///
    /// - Parameter enabled: `true` to add `-f`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Cp`` value with the flag applied.
    public func force(_ enabled: Bool = true) -> Self {
        copy(forcesReplacement: enabled)
    }

    /// Returns a copy with one additional source path appended.
    ///
    /// Sources are forwarded to `cp` in declaration order, before the destination. When more
    /// than one source is supplied, ``destination(_:)`` must refer to a directory.
    ///
    /// - Parameter path: A file or directory path to copy.
    /// - Returns: A new ``Cp`` value with the source appended.
    public func source(_ path: String) -> Self {
        copy(sources: state.sources + [path])
    }

    /// Returns a copy with multiple source paths appended.
    ///
    /// - Parameter paths: The source paths to append, in order.
    /// - Returns: A new ``Cp`` value with the sources appended.
    public func sources(_ paths: [String]) -> Self {
        copy(sources: state.sources + paths)
    }

    /// Returns a copy that uses `path` as the destination of the copy.
    ///
    /// May be a file path (when there is exactly one source and it is a file) or a directory
    /// path (when copying multiple sources or directories). Calling this multiple times keeps
    /// the last value.
    ///
    /// - Parameter path: The destination path.
    /// - Returns: A new ``Cp`` value with the destination set.
    public func destination(_ path: String) -> Self {
        copy(destinationPath: path)
    }

    /// Builds the raw `cp` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: flags, then sources, then destination. The shared
    /// ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.isRecursive {
            arguments.append("-R")
        }
        if state.forcesReplacement {
            arguments.append("-f")
        }

        if !state.sources.isEmpty || state.destinationPath != nil { arguments.append("--") }
        arguments.append(contentsOf: state.sources)

        if let destinationPath = state.destinationPath {
            arguments.append(destinationPath)
        }

        let base = Command("cp")
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
        forcesReplacement: Bool? = nil,
        sources: [String]? = nil,
        destinationPath: String?? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                isRecursive: isRecursive ?? state.isRecursive,
                forcesReplacement: forcesReplacement ?? state.forcesReplacement,
                sources: sources ?? state.sources,
                destinationPath: destinationPath ?? state.destinationPath
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isRecursive: Bool
    let forcesReplacement: Bool
    let sources: [String]
    let destinationPath: String?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isRecursive: Bool = false,
        forcesReplacement: Bool = false,
        sources: [String] = [],
        destinationPath: String? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isRecursive = isRecursive
        self.forcesReplacement = forcesReplacement
        self.sources = sources
        self.destinationPath = destinationPath
    }
}
#endif
