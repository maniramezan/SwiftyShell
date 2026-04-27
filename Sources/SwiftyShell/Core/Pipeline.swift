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
/// let output = try await Command("ls", arguments: "-la")
///     .pipe(to: Grep(".swift").command())
///     .run(in: context)
///
/// print(output.stdout)
/// ```
///
/// Add more stages by continuing to call ``pipe(to:)``:
///
/// ```swift
/// let pipeline = Command("cat", arguments: "log.txt")
///     .pipe(to: Command("grep", arguments: "ERROR"))
///     .pipe(to: Command("wc", arguments: "-l"))
///
/// let count = try await pipeline.run(in: context)
/// ```
public struct Pipeline: Sendable {
    /// The ordered command stages in the pipeline.
    ///
    /// Stages are connected stdout-to-stdin in declaration order. The first stage receives the
    /// executor's normal stdin (typically inherited from the parent process); the last stage's
    /// stdout is what ``run(in:)`` returns.
    public let stages: [Command]

    internal init(stages: [Command]) {
        self.stages = stages
    }

    /// Returns a new pipeline with `next` appended as a downstream stage.
    ///
    /// Existing stages are preserved. The current pipeline's final stage's stdout becomes
    /// `next`'s stdin.
    ///
    /// ```swift
    /// let pipeline = Command("ls", arguments: "-la")
    ///     .pipe(to: Command("grep", arguments: ".swift"))
    ///     .pipe(to: Command("wc", arguments: "-l"))   // appended via this method
    /// ```
    ///
    /// - Parameter next: The command to append as the new final stage.
    /// - Returns: A new ``Pipeline`` with the additional stage.
    public func pipe(to next: Command) -> Self {
        Self(stages: stages + [next])
    }

    /// Runs the pipeline using the provided shell context and returns the final stage's output.
    ///
    /// All stages run concurrently as separate processes; the executor wires stdout-to-stdin
    /// between them. A failure in any stage surfaces as ``ShellError`` from this call.
    ///
    /// - Parameter context: The shell context that supplies defaults to every stage. Defaults
    ///   to a freshly constructed ``ShellContext``.
    /// - Returns: The captured ``ShellOutput`` of the final stage.
    /// - Throws: ``ShellError`` if any stage fails to spawn, exits non-zero, times out, exceeds
    ///   an output limit, or is canceled.
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
