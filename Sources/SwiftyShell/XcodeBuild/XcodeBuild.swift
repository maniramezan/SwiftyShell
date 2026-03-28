import Foundation

/// A fluent wrapper for the `xcodebuild` command.
public struct XcodeBuild: RunnableCommandFamily {
    /// Shared configuration applied to commands produced by this client.
    public let config: ToolConfiguration
    /// The stdout handling strategy for built commands.
    public let stdoutDestination: OutputDestination
    /// The stderr handling strategy for built commands.
    public let stderrDestination: OutputDestination
    /// Typed `xcodebuild` options applied before build settings and trailing arguments.
    public let options: [XcodeBuildOption]
    /// Additional trailing arguments passed to `xcodebuild`.
    public let trailingArguments: [String]
    let buildSettings: [XcodeBuildBuildSetting]

    /// The shell context used when running this command family.
    public var context: ShellContext { config.context }

    /// Creates an `xcodebuild` command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
        self.stdoutDestination = .capture
        self.stderrDestination = .capture
        self.options = []
        self.trailingArguments = []
        self.buildSettings = []
    }

    private init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination,
        stderrDestination: OutputDestination,
        options: [XcodeBuildOption],
        trailingArguments: [String],
        buildSettings: [XcodeBuildBuildSetting]
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.options = options
        self.trailingArguments = trailingArguments
        self.buildSettings = buildSettings
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(config))
    }

    /// Redirects stdout for the built `xcodebuild` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `xcodebuild` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Appends a typed `xcodebuild` option.
    public func option(_ option: XcodeBuildOption) -> Self {
        copy(options: options + [option])
    }

    /// Appends multiple typed `xcodebuild` options.
    public func options(_ values: [XcodeBuildOption]) -> Self {
        copy(options: options + values)
    }

    /// Appends a trailing argument.
    public func trailingArgument(_ value: String) -> Self {
        copy(trailingArguments: trailingArguments + [value])
    }

    /// Appends multiple trailing arguments.
    public func trailingArguments(_ values: [String]) -> Self {
        copy(trailingArguments: trailingArguments + values)
    }

    /// Adds a build setting in `NAME=VALUE` form.
    public func buildSetting(_ name: String, _ value: String) -> Self {
        copy(buildSettings: buildSettings + [XcodeBuildBuildSetting(name: name, value: value)])
    }

    /// Adds multiple build settings.
    public func buildSettings(_ values: KeyValuePairs<String, String>) -> Self {
        copy(buildSettings: buildSettings + values.map { XcodeBuildBuildSetting(name: $0.0, value: $0.1) })
    }

    /// Builds the raw `xcodebuild` command.
    public func command() -> Command {
        let base = Command("xcodebuild")
            .args(options.flatMap(\.arguments))
            .args(buildSettings.map(\.argument))
            .args(trailingArguments)
            .stdout(stdoutDestination)
            .stderr(stderrDestination)

        return config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        options: [XcodeBuildOption]? = nil,
        trailingArguments: [String]? = nil,
        buildSettings: [XcodeBuildBuildSetting]? = nil
    ) -> Self {
        Self(
            config: config ?? self.config,
            stdoutDestination: stdoutDestination ?? self.stdoutDestination,
            stderrDestination: stderrDestination ?? self.stderrDestination,
            options: options ?? self.options,
            trailingArguments: trailingArguments ?? self.trailingArguments,
            buildSettings: buildSettings ?? self.buildSettings
        )
    }
}

struct XcodeBuildBuildSetting: Sendable, Equatable {
    let name: String
    let value: String

    var argument: String {
        "\(name)=\(value)"
    }
}
