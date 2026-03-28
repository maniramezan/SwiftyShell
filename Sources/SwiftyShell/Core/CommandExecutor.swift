import Foundation

/// An abstraction for running commands and pipelines.
public protocol CommandExecutor: Sendable {
    /// Executes a single command in the given shell context.
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput
    /// Executes a pipeline in the given shell context.
    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput
}
