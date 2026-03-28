import Foundation

/// Default execution settings shared by commands and pipelines.
public struct ShellContext: Sendable {
    /// Default search paths used to resolve executables by name.
    public static let defaultSearchPaths: [String] = {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        return path.split(separator: ":").map(String.init)
    }()

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
}
