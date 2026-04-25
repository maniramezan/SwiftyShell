import Foundation

/// An abstraction for running commands and pipelines.
///
/// Implement ``CommandExecutor`` to substitute a custom execution engine — for
/// example, to record commands in tests or add cross-cutting concerns like logging.
///
/// ```swift
/// // Use MockExecutor in tests:
/// let context = ShellContext(executor: MockExecutor(stdout: "main\n"))
/// let output = try await Command("git", "branch").run(in: context)
///
/// // Custom executor that logs before running:
/// struct LoggingExecutor: CommandExecutor {
///     let inner: any CommandExecutor
///     func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
///         print("Running:", command)
///         return try await inner.execute(command, in: context)
///     }
///     func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
///         print("Running pipeline:", pipeline)
///         return try await inner.execute(pipeline, in: context)
///     }
/// }
/// ```
///
/// The default executor is ``SubprocessExecutor``.
public protocol CommandExecutor: Sendable {
    /// Executes a single command in the given shell context and returns its captured output.
    ///
    /// Conformers are responsible for resolving the executable against
    /// ``ShellContext/searchPaths``, merging ``ShellContext/environment`` with
    /// ``Command/environmentOverrides``, applying any timeout and output-limit overrides, and
    /// translating non-zero exits into ``ShellError/exitFailure(command:output:)``.
    ///
    /// - Parameters:
    ///   - command: The command to run.
    ///   - context: The shell context that supplies defaults (executor, environment, working
    ///     directory, timeout, output limit).
    /// - Returns: The captured ``ShellOutput`` produced by the process.
    /// - Throws: ``ShellError`` describing why the command could not run or did not succeed.
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput

    /// Executes a pipeline in the given shell context and returns the final stage's output.
    ///
    /// Conformers are expected to connect each stage's stdout to the next stage's stdin and to
    /// run all stages concurrently. Only the last stage's captured output is returned; earlier
    /// stages may still raise ``ShellError`` if they fail.
    ///
    /// - Parameters:
    ///   - pipeline: The ordered set of commands to run as a single pipeline.
    ///   - context: The shell context that supplies defaults for every stage.
    /// - Returns: The captured ``ShellOutput`` of the final stage.
    /// - Throws: ``ShellError`` if any stage fails to launch, exits non-zero, times out, or
    ///   exceeds an output limit.
    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
}
