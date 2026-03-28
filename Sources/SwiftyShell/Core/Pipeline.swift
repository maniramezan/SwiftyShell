import Foundation

/// A sequence of commands connected through pipes.
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
