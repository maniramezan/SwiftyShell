import Foundation

/// The pattern mode used by `grep`.
public enum GrepPattern: Sendable, Equatable, Hashable {
    /// A literal string match.
    case literal(String)
    /// An extended regular expression match.
    case regularExpression(String)

    fileprivate var value: String {
        switch self {
        case let .literal(value), let .regularExpression(value):
            value
        }
    }

    fileprivate var optionArguments: [String] {
        switch self {
        case .literal:
            ["-F"]
        case .regularExpression:
            ["-E"]
        }
    }
}

/// A fluent wrapper for the `grep` command.
public struct Grep: RunnableCommandFamily {
    /// Shared configuration applied to commands produced by this client.
    public let config: ToolConfiguration
    /// The stdout handling strategy for built commands.
    public let stdoutDestination: OutputDestination
    /// The stderr handling strategy for built commands.
    public let stderrDestination: OutputDestination
    /// The grep pattern mode and value.
    public let pattern: GrepPattern
    /// Whether matches ignore case.
    public let isCaseInsensitive: Bool
    /// Whether matches are inverted.
    public let isInverted: Bool
    /// Whether grep runs recursively.
    public let isRecursive: Bool
    /// Whether matching line numbers are included.
    public let includesLineNumbers: Bool
    /// Whether grep returns only match counts.
    public let countsOnly: Bool
    /// File paths searched by grep.
    public let filePaths: [String]

    /// The shell context used when running this command family.
    public var context: ShellContext { config.context }

    /// Creates a literal-match grep command family.
    public init(_ pattern: String, context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
        self.stdoutDestination = .capture
        self.stderrDestination = .capture
        self.pattern = .literal(pattern)
        self.isCaseInsensitive = false
        self.isInverted = false
        self.isRecursive = false
        self.includesLineNumbers = false
        self.countsOnly = false
        self.filePaths = []
    }

    private init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination,
        stderrDestination: OutputDestination,
        pattern: GrepPattern,
        isCaseInsensitive: Bool,
        isInverted: Bool,
        isRecursive: Bool,
        includesLineNumbers: Bool,
        countsOnly: Bool,
        filePaths: [String]
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.pattern = pattern
        self.isCaseInsensitive = isCaseInsensitive
        self.isInverted = isInverted
        self.isRecursive = isRecursive
        self.includesLineNumbers = includesLineNumbers
        self.countsOnly = countsOnly
        self.filePaths = filePaths
    }

    /// Creates a regular-expression grep command family.
    public static func regex(_ pattern: String, context: ShellContext = .init()) -> Self {
        Self(
            config: ToolConfiguration(context: context),
            stdoutDestination: .capture,
            stderrDestination: .capture,
            pattern: .regularExpression(pattern),
            isCaseInsensitive: false,
            isInverted: false,
            isRecursive: false,
            includesLineNumbers: false,
            countsOnly: false,
            filePaths: []
        )
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(config))
    }

    /// Redirects stdout for the built `grep` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `grep` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Enables case-insensitive matching.
    public func ignoreCase(_ enabled: Bool = true) -> Self {
        copy(isCaseInsensitive: enabled)
    }

    /// Inverts the match result.
    public func invertMatch(_ enabled: Bool = true) -> Self {
        copy(isInverted: enabled)
    }

    /// Searches directories recursively.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Includes line numbers for matches.
    public func lineNumbers(_ enabled: Bool = true) -> Self {
        copy(includesLineNumbers: enabled)
    }

    /// Returns only the number of matches.
    public func count(_ enabled: Bool = true) -> Self {
        copy(countsOnly: enabled)
    }

    /// Appends a file path to search.
    public func file(_ path: String) -> Self {
        copy(filePaths: filePaths + [path])
    }

    /// Appends multiple file paths to search.
    public func files(_ paths: [String]) -> Self {
        copy(filePaths: filePaths + paths)
    }

    /// Builds the raw `grep` command.
    public func command() -> Command {
        var arguments: [String] = []

        if isCaseInsensitive {
            arguments.append("-i")
        }
        if isInverted {
            arguments.append("-v")
        }
        if isRecursive {
            arguments.append("-r")
        }
        if includesLineNumbers {
            arguments.append("-n")
        }
        if countsOnly {
            arguments.append("-c")
        }

        arguments.append(contentsOf: pattern.optionArguments)
        arguments.append("--")
        arguments.append(pattern.value)
        arguments.append(contentsOf: filePaths)

        let base = Command("grep")
            .args(arguments)
            .stdout(stdoutDestination)
            .stderr(stderrDestination)

        return config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        pattern: GrepPattern? = nil,
        isCaseInsensitive: Bool? = nil,
        isInverted: Bool? = nil,
        isRecursive: Bool? = nil,
        includesLineNumbers: Bool? = nil,
        countsOnly: Bool? = nil,
        filePaths: [String]? = nil
    ) -> Self {
        Self(
            config: config ?? self.config,
            stdoutDestination: stdoutDestination ?? self.stdoutDestination,
            stderrDestination: stderrDestination ?? self.stderrDestination,
            pattern: pattern ?? self.pattern,
            isCaseInsensitive: isCaseInsensitive ?? self.isCaseInsensitive,
            isInverted: isInverted ?? self.isInverted,
            isRecursive: isRecursive ?? self.isRecursive,
            includesLineNumbers: includesLineNumbers ?? self.includesLineNumbers,
            countsOnly: countsOnly ?? self.countsOnly,
            filePaths: filePaths ?? self.filePaths
        )
    }
}
