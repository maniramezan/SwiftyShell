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
    public static let defaultSearchPaths: [String] = defaultSearchPaths(
        environment: ProcessInfo.processInfo.environment
    )

    /// The executor responsible for running commands and pipelines.
    public let executor: any CommandExecutor
    /// Search paths used to resolve executable names.
    public let searchPaths: [String]
    /// Base environment variables used for command execution.
    public let environment: [String: String]
    /// An optional default working directory.
    public let workingDirectory: String?
    /// An optional default timeout in seconds.
    public let defaultTimeout: TimeInterval?
    /// The default maximum captured output size in bytes.
    public let defaultOutputLimit: Int

    /// Creates a shell context with execution defaults.
    ///
    /// - Parameter executor: The executor responsible for running commands and pipelines.
    /// - Parameter searchPaths: The search paths used to resolve executable names.
    /// - Parameter environment: The base environment variables used for command execution.
    /// - Parameter workingDirectory: The default working directory for commands that do not override it.
    /// - Parameter defaultTimeout: The default timeout in seconds for commands that do not override it. The value must be greater than or equal to zero when provided.
    /// - Parameter defaultOutputLimit: The maximum captured output size in bytes for commands that do not override it. The value must be greater than or equal to zero.
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
