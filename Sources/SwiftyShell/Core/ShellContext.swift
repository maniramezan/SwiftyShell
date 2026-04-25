import Foundation

/// A supported operating-system family used to derive shell execution defaults.
///
/// Use ``ShellPlatform`` when you need to choose platform-specific executable
/// search paths while building custom command families or contexts.
///
/// ```swift
/// let platform = ShellPlatform.current
/// let paths = platform.defaultSearchPaths
/// let context = ShellContext(searchPaths: paths)
/// ```
public enum ShellPlatform: Sendable {
    /// The macOS platform family.
    case macOS
    /// The Linux platform family.
    case linux

    /// The platform for the current compilation target.
    public static let current: Self = {
        #if os(macOS)
        .macOS
        #elseif os(Linux)
        .linux
        #else
        .macOS
        #endif
    }()

    /// The default executable search paths for this platform.
    public var defaultSearchPaths: [String] {
        switch self {
        case .macOS:
            ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/usr/local/bin"]
        case .linux:
            ["/usr/local/sbin", "/usr/local/bin", "/usr/sbin", "/usr/bin", "/sbin", "/bin"]
        }
    }
}

/// Default execution settings shared by commands and pipelines.
///
/// ``ShellContext`` carries the executor, search paths, environment variables,
/// default working directory, default timeout, and default output limit that
/// every command and pipeline uses. Individual commands can override any
/// setting per-call; context values act as the fallback.
///
/// **Override precedence** — highest to lowest:
/// 1. A per-command override (e.g. ``Command/timeout(_:)``)
/// 2. The context default (e.g. `ShellContext(defaultTimeout: 30)`)
/// 3. The platform default (search paths) or no constraint (timeout, output limit)
///
/// ```swift
/// // Shared context for the whole program
/// let context = ShellContext(
///     workingDirectory: "/var/app",
///     defaultTimeout: 30,
///     defaultOutputLimit: 5_242_880   // 5 MB
/// )
///
/// // Override per command — does not mutate the context
/// try await Command("swift", "build", "--verbose")
///     .timeout(300)                   // overrides the 30-second default for this call only
///     .run(in: context)
/// ```
///
/// Pass the same context to typed command families and raw ``Command`` values
/// so they share search paths, environment variables, and — critically — the
/// executor (essential for ``MockExecutor``-based tests, where every command
/// must share the same mock).
public struct ShellContext: Sendable {
    /// Default search paths used to resolve executables by name.
    ///
    /// Computed once at process start by reading the parent process's `PATH` (via
    /// `ProcessInfo.processInfo.environment`) and falling back to the platform defaults from
    /// ``ShellPlatform/defaultSearchPaths`` when `PATH` is missing or empty.
    public static let defaultSearchPaths: [String] = defaultSearchPaths(
        environment: ProcessInfo.processInfo.environment
    )

    /// The executor responsible for running commands and pipelines.
    ///
    /// Defaults to ``SubprocessExecutor`` (real process execution). Substitute ``MockExecutor``
    /// in tests to capture commands without spawning processes.
    public let executor: any CommandExecutor

    /// Search paths used to resolve executable names.
    ///
    /// Used by the executor when ``Command/executableName`` is a bare program name. Paths are
    /// tried in order; the first existing executable wins. Ignored when an explicit path is
    /// supplied via ``Command/executable(_:)``.
    public let searchPaths: [String]

    /// Base environment variables used for command execution.
    ///
    /// Per-command overrides (``Command/env(_:_:)``, ``Command/env(_:)``) are merged on top of
    /// this dictionary at execution time. Defaults to the parent process's environment.
    public let environment: [String: String]

    /// An optional default working directory inherited by every command.
    ///
    /// Per-command overrides via ``Command/workingDirectory(_:)`` take precedence. When `nil`,
    /// the executor inherits the calling process's current working directory.
    public let workingDirectory: String?

    /// An optional default timeout in seconds applied to every command.
    ///
    /// When `nil`, commands run without a timeout unless one is supplied via
    /// ``Command/timeout(_:)``. Negative values raise
    /// ``ShellError/invalidConfiguration(description:)`` at execution time.
    public let defaultTimeout: TimeInterval?

    /// The default maximum captured output size in bytes.
    ///
    /// Applies to the combined captured stdout and stderr per command. When exceeded, the
    /// executor raises ``ShellError/outputLimitExceeded(command:limit:partialOutput:)``.
    /// Defaults to `10_485_760` (10 MB). Per-command overrides via ``Command/outputLimit(_:)``
    /// take precedence.
    public let defaultOutputLimit: Int

    /// Creates a shell context with execution defaults.
    ///
    /// All parameters have sensible defaults for ad-hoc use; supply specific values when you want
    /// the same defaults to apply across many commands (for example a fixed working directory
    /// for an entire CLI subcommand, or a global timeout for safety).
    ///
    /// - Parameters:
    ///   - executor: The executor responsible for running commands and pipelines. Defaults to
    ///     ``SubprocessExecutor``; use ``MockExecutor`` in tests.
    ///   - searchPaths: The search paths used to resolve executable names by their bare name.
    ///     Defaults to ``defaultSearchPaths``.
    ///   - environment: The base environment variables used for command execution. Defaults to
    ///     `ProcessInfo.processInfo.environment`.
    ///   - workingDirectory: The default working directory for commands that do not override it.
    ///     Pass `nil` (the default) to inherit the calling process's working directory.
    ///   - defaultTimeout: The default timeout in seconds for commands that do not override it.
    ///     Must be `>= 0` when provided. Pass `nil` (the default) to leave commands unbounded.
    ///   - defaultOutputLimit: The maximum captured output size in bytes for commands that do
    ///     not override it. Must be `>= 0`. Defaults to `10_485_760` (10 MB).
    public init(
        executor: any CommandExecutor = SubprocessExecutor(),
        searchPaths: [String] = ShellContext.defaultSearchPaths,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        workingDirectory: String? = nil,
        defaultTimeout: TimeInterval? = nil,
        defaultOutputLimit: Int = 10_485_760
    ) {
        self.executor = executor
        self.searchPaths = searchPaths
        self.environment = environment
        self.workingDirectory = workingDirectory
        self.defaultTimeout = defaultTimeout
        self.defaultOutputLimit = defaultOutputLimit
    }

    /// Resolves executable search paths from an environment dictionary.
    ///
    /// This uses the `PATH` entry when it is present and non-empty. Otherwise it
    /// falls back to the default paths for the supplied platform.
    ///
    /// - Parameter environment: The environment dictionary to inspect.
    /// - Parameter platform: The platform whose default paths should be used when `PATH` is missing or empty.
    /// - Returns: The resolved executable search paths.
    public static func defaultSearchPaths(
        environment: [String: String],
        platform: ShellPlatform = .current
    ) -> [String] {
        guard let path = environment["PATH"], path.isEmpty == false else {
            return platform.defaultSearchPaths
        }

        return path.split(separator: ":").map(String.init)
    }
}
