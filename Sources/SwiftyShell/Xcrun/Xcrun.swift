import Foundation

/// A fluent wrapper for the `xcrun` command.
public struct Xcrun: RunnableCommandFamily {
    /// Shared configuration applied to commands produced by this client.
    public let config: ToolConfiguration
    /// The stdout handling strategy for built commands.
    public let stdoutDestination: OutputDestination
    /// The stderr handling strategy for built commands.
    public let stderrDestination: OutputDestination
    /// Typed `xcrun` options applied before trailing arguments.
    public let options: [XcrunOption]
    /// Trailing tool and argument values passed to `xcrun`.
    public let trailingArguments: [String]

    /// The shell context used when running this command family.
    public var context: ShellContext { config.context }

    /// Creates an `xcrun` command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
        self.stdoutDestination = .capture
        self.stderrDestination = .capture
        self.options = []
        self.trailingArguments = []
    }

    private init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination,
        stderrDestination: OutputDestination,
        options: [XcrunOption],
        trailingArguments: [String]
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.options = options
        self.trailingArguments = trailingArguments
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(config))
    }

    /// Redirects stdout for the built `xcrun` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `xcrun` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Appends a typed `xcrun` option.
    public func option(_ option: XcrunOption) -> Self {
        copy(options: options + [option])
    }

    /// Appends multiple typed `xcrun` options.
    public func options(_ values: [XcrunOption]) -> Self {
        copy(options: options + values)
    }

    /// Appends a tool name such as `simctl`.
    public func tool(_ value: String) -> Self {
        trailingArgument(value)
    }

    /// Appends a trailing argument.
    public func trailingArgument(_ value: String) -> Self {
        copy(trailingArguments: trailingArguments + [value])
    }

    /// Appends multiple trailing arguments.
    public func trailingArguments(_ values: [String]) -> Self {
        copy(trailingArguments: trailingArguments + values)
    }

    /// Enters the typed `simctl` command family.
    public func simctl() -> Simctl {
        Simctl(xcrun: self)
    }

    /// Builds the raw `xcrun` command.
    public func command() -> Command {
        let base = Command("xcrun")
            .args(options.flatMap(\.arguments))
            .args(trailingArguments)
            .stdout(stdoutDestination)
            .stderr(stderrDestination)

        return config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        options: [XcrunOption]? = nil,
        trailingArguments: [String]? = nil
    ) -> Self {
        Self(
            config: config ?? self.config,
            stdoutDestination: stdoutDestination ?? self.stdoutDestination,
            stderrDestination: stderrDestination ?? self.stderrDestination,
            options: options ?? self.options,
            trailingArguments: trailingArguments ?? self.trailingArguments
        )
    }
}
