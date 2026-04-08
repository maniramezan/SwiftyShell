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
    /// Executes a single command in the given shell context.
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput
    /// Executes a pipeline in the given shell context.
    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
}
