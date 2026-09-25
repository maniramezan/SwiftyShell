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
    private var state: State

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
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that selects a Makefile with `--file <path>`.
    public func file(_ path: String) -> Self { modified(self) { $0.state.filePath = path } }

    /// Returns a copy that changes make's directory with `--directory <path>`.
    public func directory(_ path: String) -> Self { modified(self) { $0.state.directoryPath = path } }

    /// Returns a copy that sets parallelism with `--jobs <count>`.
    public func jobs(_ count: Int) -> Self { modified(self) { $0.state.jobCount = count } }

    /// Returns a copy that passes `--keep-going`.
    public func keepGoing(_ enabled: Bool = true) -> Self { modified(self) { $0.state.keepsGoing = enabled } }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isSilent = enabled } }

    /// Returns a copy that passes `--dry-run`.
    public func dryRun(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isDryRun = enabled } }

    /// Returns a copy that passes `--always-make`.
    public func alwaysMake(_ enabled: Bool = true) -> Self { modified(self) { $0.state.alwaysMakes = enabled } }

    /// Returns a copy that appends a raw option or variable assignment before targets.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw options or variable assignments before targets.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends a make target.
    public func target(_ name: String) -> Self { modified(self) { $0.state.targets += [name] } }

    /// Returns a copy that appends multiple make targets.
    public func targets(_ names: [String]) -> Self { modified(self) { $0.state.targets += names } }

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
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var filePath: String? = nil
    var directoryPath: String? = nil
    var jobCount: Int? = nil
    var keepsGoing: Bool = false
    var isSilent: Bool = false
    var isDryRun: Bool = false
    var alwaysMakes: Bool = false
    var extraArguments: [String] = []
    var targets: [String] = []
}
#endif
