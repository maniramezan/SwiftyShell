import Foundation

/// A typed command family that supports standard tool configuration overrides.
///
/// Conform to ``ToolConfigurableCommandFamily`` to inherit fluent helpers for
/// `executable`, `env`, `workingDirectory`, `timeout`, and `outputLimit`:
///
/// ```swift
/// struct MyCLI: ToolConfigurableCommandFamily {
///     let config: ToolConfiguration
///     var context: ShellContext { config.context }
///
///     init(context: ShellContext = .init()) {
///         self.config = ToolConfiguration(context: context)
///     }
///
///     func updatingConfiguration(
///         _ update: (ToolConfiguration) -> ToolConfiguration
///     ) -> Self {
///         Self(config: update(config))
///     }
/// }
///
/// // All fluent overrides are available automatically:
/// let cli = MyCLI()
///     .workingDirectory("/tmp")
///     .env("DEBUG", "1")
///     .timeout(30)
/// ```
public protocol ToolConfigurableCommandFamily: Sendable {
    /// The shell context used when running commands built by this family.
    ///
    /// Conformers typically forward this from a stored ``ToolConfiguration`` so that
    /// `family.run()` and `family.command().run(in: family.context)` use the same executor.
    var context: ShellContext { get }

    /// Returns a new value with an updated tool configuration.
    ///
    /// The shared fluent helpers (``executable(_:)``, ``env(_:_:)``, ``workingDirectory(_:)``,
    /// ``timeout(_:)``, ``outputLimit(_:)``) all funnel through this method, so a single
    /// implementation per family is enough to wire up every override.
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new instance whose ``ToolConfiguration`` reflects `update`'s result.
    func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self
}

/// Shared fluent helpers for command families that expose tool configuration overrides.
public extension ToolConfigurableCommandFamily {
    /// Returns a copy of the family that uses the given executable path for built commands.
    ///
    /// Use this to bypass ``ShellContext/searchPaths`` resolution and pin the family to a
    /// specific binary (for example a Homebrew install or a vendored tool).
    ///
    /// - Parameter path: An absolute or relative path to the executable.
    /// - Returns: A new family value with the executable override applied.
    func executable(_ path: String) -> Self {
        updatingConfiguration { $0.executable(path) }
    }

    /// Returns a copy of the family with one environment variable set or replaced.
    ///
    /// The override is merged on top of ``ShellContext/environment`` when commands built by this
    /// family run. Calling this multiple times with the same `name` keeps the last value.
    ///
    /// - Parameters:
    ///   - name: The environment variable name.
    ///   - value: The value to assign for commands built by this family.
    /// - Returns: A new family value with the environment override applied.
    func env(_ name: String, _ value: String) -> Self {
        updatingConfiguration { $0.env(name, value) }
    }

    /// Returns a copy of the family with multiple environment variable overrides merged in.
    ///
    /// Keys in `values` win over any overrides previously applied to the family.
    ///
    /// - Parameter values: A dictionary of environment variable name/value pairs to merge.
    /// - Returns: A new family value with the merged environment overrides applied.
    func env(_ values: [String: String]) -> Self {
        updatingConfiguration { $0.env(values) }
    }

    /// Returns a copy of the family that runs built commands in the given directory.
    ///
    /// The path replaces ``ShellContext/workingDirectory`` for commands built by this family.
    ///
    /// - Parameter path: The directory in which to spawn commands.
    /// - Returns: A new family value with the working-directory override applied.
    func workingDirectory(_ path: String) -> Self {
        updatingConfiguration { $0.workingDirectory(path) }
    }

    /// Returns a copy of the family with a per-command timeout in seconds.
    ///
    /// Replaces ``ShellContext/defaultTimeout`` for commands built by this family. Must be
    /// `>= 0`; negative values raise ``ShellError/invalidConfiguration(description:)`` at
    /// execution time. See ``Command/timeout(_:)`` for the underlying semantics.
    ///
    /// - Parameter seconds: The maximum duration to wait for built commands, in seconds.
    /// - Returns: A new family value with the timeout override applied.
    func timeout(_ seconds: TimeInterval) -> Self {
        updatingConfiguration { $0.timeout(seconds) }
    }

    /// Returns a copy of the family with a per-command captured-output limit in bytes.
    ///
    /// Replaces ``ShellContext/defaultOutputLimit`` for commands built by this family. Must be
    /// `>= 0`. See ``Command/outputLimit(_:)`` for the underlying semantics.
    ///
    /// - Parameter bytes: The maximum number of captured-output bytes to retain in memory.
    /// - Returns: A new family value with the output-limit override applied.
    func outputLimit(_ bytes: Int) -> Self {
        updatingConfiguration { $0.outputLimit(bytes) }
    }
}

/// A typed command family that supports explicit stdout and stderr destinations.
///
/// Conform to this protocol when a family needs to expose ``stdout(_:)`` and ``stderr(_:)``
/// helpers so callers can redirect either stream to a file, discard it, or keep the default
/// in-memory capture. Implement the two `setting…` methods on the family; the public
/// ``stdout(_:)`` and ``stderr(_:)`` helpers are provided for free in the extension below.
public protocol OutputRedirectingCommandFamily: ToolConfigurableCommandFamily {
    /// Returns a new value with the stdout destination updated.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream of commands
    ///   built by this family.
    /// - Returns: A new family value with the stdout destination applied.
    func settingStdoutDestination(_ destination: OutputDestination) -> Self

    /// Returns a new value with the stderr destination updated.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream of commands
    ///   built by this family.
    /// - Returns: A new family value with the stderr destination applied.
    func settingStderrDestination(_ destination: OutputDestination) -> Self
}

/// Shared fluent helpers for command families that expose stdout and stderr redirection.
public extension OutputRedirectingCommandFamily {
    /// Returns a copy of the family that routes built commands' stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. See ``Command/stdout(_:)`` for the full set of
    /// destinations and their semantics.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new family value with the stdout destination applied.
    func stdout(_ destination: OutputDestination) -> Self {
        settingStdoutDestination(destination)
    }

    /// Returns a copy of the family that routes built commands' stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. See ``Command/stderr(_:)`` for the full set of
    /// destinations and their semantics.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new family value with the stderr destination applied.
    func stderr(_ destination: OutputDestination) -> Self {
        settingStderrDestination(destination)
    }
}

/// A typed command family that can materialize a `Command` and run it.
///
/// ``RunnableCommandFamily`` combines ``OutputRedirectingCommandFamily`` with the ability to
/// build a raw ``Command`` and execute it. The default `run()` implementation calls
/// ``command()`` and runs it in the configured ``ToolConfigurableCommandFamily/context``.
///
/// ```swift
/// struct MyTool: RunnableCommandFamily {
///     // ... (see ToolConfigurableCommandFamily for conformance boilerplate)
///
///     func command() -> Command {
///         config.apply(to: Command("my-tool").args(["--flag"]))
///     }
/// }
///
/// let output = try await MyTool().run()
/// ```
public protocol RunnableCommandFamily: OutputRedirectingCommandFamily {
    /// Builds the raw ``Command`` represented by the current fluent configuration.
    ///
    /// Conformers should compose argv from the family's stored state, then call
    /// ``ToolConfiguration/apply(to:)`` so that any executable, environment, working-directory,
    /// timeout, and output-limit overrides are merged onto the returned command.
    ///
    /// - Returns: A ``Command`` ready to be executed via ``Command/run(in:)`` or composed into a
    ///   ``Pipeline``.
    func command() -> Command
}

/// Shared execution helpers for command families that can build a `Command`.
public extension RunnableCommandFamily {
    /// Runs the command represented by the current fluent configuration.
    ///
    /// Equivalent to `try await command().run(in: context)`. Override this method only when the
    /// family needs to perform additional work around execution (for example to parse output
    /// into a typed result).
    ///
    /// - Returns: The captured ``ShellOutput`` produced by the built command.
    /// - Throws: ``ShellError`` describing the failure mode if execution fails.
    func run() async throws -> ShellOutput {
        try await command().run(in: context)
    }
}
