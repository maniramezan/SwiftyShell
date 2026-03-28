import Foundation

/// A typed command family that supports standard tool configuration overrides.
public protocol ToolConfigurableCommandFamily: Sendable {
    /// The shell context used when running commands built by this family.
    var context: ShellContext { get }

    /// Returns a new value with an updated tool configuration.
    func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self
}

/// Shared fluent helpers for command families that expose tool configuration overrides.
public extension ToolConfigurableCommandFamily {
    /// Overrides the executable used for this command family.
    func executable(_ path: String) -> Self {
        updatingConfiguration { $0.executable(path) }
    }

    /// Adds or replaces a single environment variable override.
    func env(_ name: String, _ value: String) -> Self {
        updatingConfiguration { $0.env(name, value) }
    }

    /// Merges environment variable overrides into the command family configuration.
    func env(_ values: [String: String]) -> Self {
        updatingConfiguration { $0.env(values) }
    }

    /// Overrides the working directory used when running the command.
    func workingDirectory(_ path: String) -> Self {
        updatingConfiguration { $0.workingDirectory(path) }
    }

    /// Overrides the timeout used when running the command.
    func timeout(_ seconds: TimeInterval) -> Self {
        updatingConfiguration { $0.timeout(seconds) }
    }

    /// Overrides the output limit used when capturing command output.
    func outputLimit(_ bytes: Int) -> Self {
        updatingConfiguration { $0.outputLimit(bytes) }
    }
}

/// A typed command family that supports explicit stdout and stderr destinations.
public protocol OutputRedirectingCommandFamily: ToolConfigurableCommandFamily {
    /// Returns a new value with an updated stdout destination.
    func settingStdoutDestination(_ destination: OutputDestination) -> Self
    /// Returns a new value with an updated stderr destination.
    func settingStderrDestination(_ destination: OutputDestination) -> Self
}

/// Shared fluent helpers for command families that expose stdout and stderr redirection.
public extension OutputRedirectingCommandFamily {
    /// Redirects stdout for commands built by this family.
    func stdout(_ destination: OutputDestination) -> Self {
        settingStdoutDestination(destination)
    }

    /// Redirects stderr for commands built by this family.
    func stderr(_ destination: OutputDestination) -> Self {
        settingStderrDestination(destination)
    }
}

/// A typed command family that can materialize a `Command` and run it.
public protocol RunnableCommandFamily: OutputRedirectingCommandFamily {
    /// Builds the raw `Command` represented by the current fluent configuration.
    func command() -> Command
}

/// Shared execution helpers for command families that can build a `Command`.
public extension RunnableCommandFamily {
    /// Runs the command represented by the current fluent configuration.
    func run() async throws -> ShellOutput {
        try await command().run(in: context)
    }
}
