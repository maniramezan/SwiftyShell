import Foundation

/// A sequence of commands connected through pipes.
///
/// Build a ``Pipeline`` by calling ``Command/pipe(to:)`` on the first command,
/// then chain additional stages with ``pipe(to:)``:
///
/// This builds `ls -la | grep .swift` without asking a shell to parse a pipeline string. The final
/// stage's output is returned as ``ShellOutput``.
///
/// ```swift
/// let output = try await Command("ls", "-la")
///     .pipe(to: Grep(".swift").command())
///     .run(in: context)
///
/// print(output.stdout)
/// ```
///
/// Add more stages by continuing to call ``pipe(to:)``:
///
/// ```swift
/// let pipeline = Command("cat", "log.txt")
///     .pipe(to: Command("grep", "ERROR"))
///     .pipe(to: Command("wc", "-l"))
///
/// let count = try await pipeline.run(in: context)
/// ```
public struct Pipeline: Sendable {
    /// The ordered command stages in the pipeline.
    public let stages: [Command]

    internal init(stages: [Command]) {
        self.stages = stages
    }

    /// Appends another command to the pipeline.
    public func pipe(to next: Command) -> Self {
        Self(stages: stages + [next])
    }

    /// Runs the pipeline using the provided shell context.
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput {
        try await context.executor.execute(self, in: context)
    }
}

extension Pipeline: CustomStringConvertible {
    /// Returns the pipeline as it would appear on the command line.
    public var description: String {
        stages.map(\.description).joined(separator: " | ")
    }
}

extension Pipeline: CustomDebugStringConvertible {
    /// Returns a detailed debug representation showing each stage's debug description.
    public var debugDescription: String {
        "Pipeline(\(stages.map(\.debugDescription).joined(separator: " | ")))"
    }
}
