import Foundation

/// A typed `xcrun` option and its raw arguments.
public struct XcrunOption: Sendable, Equatable, Hashable {
    /// The raw arguments emitted for the option.
    public let arguments: [String]

    /// Creates an `xcrun` option from raw arguments.
    public init(_ arguments: String...) {
        precondition(!arguments.isEmpty, "An xcrun option must include at least one argument.")
        self.arguments = arguments
    }

    private init(arguments: [String]) {
        precondition(!arguments.isEmpty, "An xcrun option must include at least one argument.")
        self.arguments = arguments
    }

    /// Creates a custom `xcrun` option.
    public static func custom(_ flag: String, values: String...) -> Self {
        Self(arguments: [flag] + values)
    }

    /// Emits `--help`.
    public static let help = Self("--help")
    /// Emits `--version`.
    public static let version = Self("--version")
    /// Emits `--verbose`.
    public static let verbose = Self("--verbose")
    /// Emits `--log`.
    public static let log = Self("--log")
    /// Emits `--find`.
    public static let find = Self("--find")
    /// Emits `--run`.
    public static let run = Self("--run")
    /// Emits `--no-cache`.
    public static let noCache = Self("--no-cache")
    /// Emits `--kill-cache`.
    public static let killCache = Self("--kill-cache")
    /// Emits `--sdk <value>`.
    public static func sdk(_ value: String) -> Self {
        Self("--sdk", value)
    }
    /// Emits `--toolchain <value>`.
    public static func toolchain(_ value: String) -> Self {
        Self("--toolchain", value)
    }
    /// Emits `--show-sdk-path`.
    public static let showSDKPath = Self("--show-sdk-path")
    /// Emits `--show-sdk-version`.
    public static let showSDKVersion = Self("--show-sdk-version")
    /// Emits `--show-sdk-build-version`.
    public static let showSDKBuildVersion = Self("--show-sdk-build-version")
    /// Emits `--show-sdk-platform-path`.
    public static let showSDKPlatformPath = Self("--show-sdk-platform-path")
    /// Emits `--show-sdk-platform-version`.
    public static let showSDKPlatformVersion = Self("--show-sdk-platform-version")
    /// Emits `--show-toolchain-path`.
    public static let showToolchainPath = Self("--show-toolchain-path")
}
