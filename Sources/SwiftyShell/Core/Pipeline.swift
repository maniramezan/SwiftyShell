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
    /// Stages are connected stdout-to-stdin in declaration order. The first stage reads its own
    /// ``Command/stdinSource`` (an empty stdin by default); the last stage's stdout is what
    /// ``run(in:)`` returns. Setting an input source on a later stage is rejected with
    /// ``ShellError/invalidConfiguration(description:)`` before any stage starts.
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
    ///     // Appended via this method.
    ///     .pipe(to: Command("wc", arguments: "-l"))
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
    /// between them. The shortest configured stage timeout governs the pipeline. Each stage has
    /// its own captured-output limit; intermediate stdout is piped rather than captured.
    ///
    /// - Parameter context: The shell context that supplies defaults to every stage. Defaults
    ///   to a freshly constructed ``ShellContext``.
    /// - Returns: The captured ``ShellOutput`` of the final stage.
    /// - Throws: With the built-in executor, ``ShellError`` if a stage fails to spawn, exits
    ///   non-zero, times out, exceeds an output limit, or is canceled. A non-final stage terminated
    ///   by `SIGPIPE` is not a failure: it means a downstream stage stopped reading early, as in
    ///   `yes | head -n 1`. Custom executors may throw other errors.
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput {
        try await context.executor.execute(self, in: context)
    }
}

extension Pipeline {
    /// Runs the pipeline and reports how every stage ended, without failing on exit codes.
    ///
    /// ``run(in:)`` stops at the first failing stage and reports only that one, like a shell with
    /// `pipefail`. Use this when each stage's exit code matters, as in `diff a b | head`, where the
    /// first stage's exit `1` means "different" rather than "broken". No stage's exit code, accepted
    /// or not, raises ``ShellError/exitFailure(command:output:)-enum.case``, so a failure in one stage
    /// does not stop the others. Launch failures, timeouts, output-limit overflows, and cancellation
    /// still throw.
    ///
    /// ```swift
    /// let result = try await Command("grep", arguments: "TODO", "Package.swift")
    ///     .pipe(to: Command("wc", arguments: "-l"))
    ///     .runReportingStages(in: context)
    /// let grepFoundNothing = result.stageExitCodes[0] == 1
    /// ```
    ///
    /// - Parameter context: The shell context that supplies defaults to every stage.
    /// - Returns: The final stage's output and the exit code of every stage.
    /// - Throws: ``ShellError`` for any failure that is not an exit code. Custom executors that do not
    ///   implement ``CommandExecutor/executeReportingStages(_:in:)`` throw
    ///   ``ShellError/invalidConfiguration(description:)``.
    public func runReportingStages(in context: ShellContext = .init()) async throws -> PipelineResult {
        try await context.executor.executeReportingStages(self, in: context)
    }

    /// Throws when a stage other than the first sets an ``InputSource``.
    ///
    /// Later stages read the previous stage's stdout, so their own source could never be used.
    /// Executors call this before starting any stage.
    func validateInputSources() throws {
        guard stages.dropFirst().allSatisfy({ $0.stdinSource == .none }) else {
            throw ShellError.invalidConfiguration(
                description:
                    "Only the first pipeline stage may set stdin; later stages read the previous stage's stdout"
            )
        }
    }
}

/// The result of ``Pipeline/runReportingStages(in:)``: the final output plus every stage's exit code.
public struct PipelineResult: Sendable, Equatable {
    /// The final stage's stdout with every stage's stderr concatenated in stage order.
    ///
    /// ``ShellOutput/exitCode`` is the final stage's exit code.
    public let output: ShellOutput

    /// The exit code of each stage in pipeline order.
    ///
    /// A stage terminated by a signal reports `128 + signal`. A stage that was cancelled before it
    /// finished reports `-1`.
    public let stageExitCodes: [Int32]

    /// Creates a pipeline result.
    ///
    /// - Parameters:
    ///   - output: The final stage's stdout with every stage's stderr.
    ///   - stageExitCodes: The exit code of each stage in pipeline order.
    public init(output: ShellOutput, stageExitCodes: [Int32]) {
        self.output = output
        self.stageExitCodes = stageExitCodes
    }

    /// Whether every stage exited with code `0`.
    public var allStagesSucceeded: Bool {
        stageExitCodes.allSatisfy { $0 == 0 }
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
