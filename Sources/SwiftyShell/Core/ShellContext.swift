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
/// Use ``ShellContext`` to provide shared environment variables, executable search
/// paths, working-directory defaults, and execution limits for one or more shell
/// operations.
///
/// ```swift
/// let context = ShellContext(
///     searchPaths: ShellPlatform.current.defaultSearchPaths,
///     workingDirectory: "/tmp"
/// )
/// let output = try await Command("pwd").run(in: context)
/// ```
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
