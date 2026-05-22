#if Make
import Foundation

/// A fluent wrapper for the `make` build automation CLI.
///
/// ``Make`` models common scripting options such as Makefile selection,
/// working directory, parallel jobs, and target lists while preserving raw
/// escape hatches for project-specific variables and flags.
///
/// ```swift
/// try await Make()
///     .file("Makefile")
///     .jobs(8)
///     .target("check")
///     .run()
/// ```
public struct Make: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Make command family bound to a shell context.
    ///
    /// - Parameter context: The shell context whose executor, search paths,
    ///   environment, and defaults will be used.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects a Makefile with `--file <path>`.
    public func file(_ path: String) -> Self { copy(filePath: path) }

    /// Returns a copy that changes make's directory with `--directory <path>`.
    public func directory(_ path: String) -> Self { copy(directoryPath: path) }

    /// Returns a copy that sets parallelism with `--jobs <count>`.
    public func jobs(_ count: Int) -> Self { copy(jobCount: count) }

    /// Returns a copy that passes `--keep-going`.
    public func keepGoing(_ enabled: Bool = true) -> Self { copy(keepsGoing: enabled) }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { copy(isSilent: enabled) }

    /// Returns a copy that passes `--dry-run`.
    public func dryRun(_ enabled: Bool = true) -> Self { copy(isDryRun: enabled) }

    /// Returns a copy that passes `--always-make`.
    public func alwaysMake(_ enabled: Bool = true) -> Self { copy(alwaysMakes: enabled) }

    /// Returns a copy that appends a raw option or variable assignment before targets.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw options or variable assignments before targets.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a make target.
    public func target(_ name: String) -> Self { copy(targets: state.targets + [name]) }

    /// Returns a copy that appends multiple make targets.
    public func targets(_ names: [String]) -> Self { copy(targets: state.targets + names) }

    /// Builds the raw `make` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        appendOption("--file", state.filePath, to: &arguments)
        appendOption("--directory", state.directoryPath, to: &arguments)
        if let jobCount = state.jobCount { arguments += ["--jobs", String(jobCount)] }
        if state.keepsGoing { arguments.append("--keep-going") }
        if state.isSilent { arguments.append("--silent") }
        if state.isDryRun { arguments.append("--dry-run") }
        if state.alwaysMakes { arguments.append("--always-make") }
        arguments += state.extraArguments + state.targets

        let base = Command("make").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        filePath: String?? = nil,
        directoryPath: String?? = nil,
        jobCount: Int?? = nil,
        keepsGoing: Bool? = nil,
        isSilent: Bool? = nil,
        isDryRun: Bool? = nil,
        alwaysMakes: Bool? = nil,
        extraArguments: [String]? = nil,
        targets: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                filePath: filePath ?? state.filePath,
                directoryPath: directoryPath ?? state.directoryPath,
                jobCount: jobCount ?? state.jobCount,
                keepsGoing: keepsGoing ?? state.keepsGoing,
                isSilent: isSilent ?? state.isSilent,
                isDryRun: isDryRun ?? state.isDryRun,
                alwaysMakes: alwaysMakes ?? state.alwaysMakes,
                extraArguments: extraArguments ?? state.extraArguments,
                targets: targets ?? state.targets
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let filePath: String?
    let directoryPath: String?
    let jobCount: Int?
    let keepsGoing: Bool
    let isSilent: Bool
    let isDryRun: Bool
    let alwaysMakes: Bool
    let extraArguments: [String]
    let targets: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        filePath: String? = nil,
        directoryPath: String? = nil,
        jobCount: Int? = nil,
        keepsGoing: Bool = false,
        isSilent: Bool = false,
        isDryRun: Bool = false,
        alwaysMakes: Bool = false,
        extraArguments: [String] = [],
        targets: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.filePath = filePath
        self.directoryPath = directoryPath
        self.jobCount = jobCount
        self.keepsGoing = keepsGoing
        self.isSilent = isSilent
        self.isDryRun = isDryRun
        self.alwaysMakes = alwaysMakes
        self.extraArguments = extraArguments
        self.targets = targets
    }
}

private func appendOption(_ name: String, _ value: String?, to arguments: inout [String]) {
    if let value { arguments += [name, value] }
}
#endif
