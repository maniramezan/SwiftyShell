import Foundation

/// A test-double implementation of ``CommandExecutor`` that returns caller-controlled
/// responses without spawning real processes.
///
/// Use ``MockExecutor`` in unit tests to verify that your code calls the right
/// commands without relying on the filesystem or external tools.
///
/// ```swift
/// // Always succeed with fixed output
/// let context = ShellContext(executor: MockExecutor(stdout: "hello\n"))
/// let output = try await Command("echo", "hello").run(in: context)
///
/// // Inspect what was called
/// var recorded: [Command] = []
/// let mock = MockExecutor { command, _ in
///     recorded.append(command)
///     return ShellOutput(stdout: "ok\n", stderr: "", exitCode: 0)
/// }
/// ```
public struct MockExecutor: CommandExecutor {
    /// The handler type invoked for each ``Command`` execution.
    public typealias Handler = @Sendable (Command, ShellContext) async throws -> ShellOutput

    private let handler: Handler

    /// Creates a mock executor that invokes `handler` for every command.
    ///
    /// - Parameter handler: Closure receiving the command and context; returns
    ///   the ``ShellOutput`` to report back to the caller or throws a ``ShellError``.
    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Creates a mock executor that always returns a fixed successful response.
    ///
    /// - Parameters:
    ///   - stdout: The stdout string to return. Defaults to `""`.
    ///   - stderr: The stderr string to return. Defaults to `""`.
    ///   - exitCode: The exit code to return. Defaults to `0`.
    public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0) {
        self.init { _, _ in
            ShellOutput(stdout: stdout, stderr: stderr, exitCode: exitCode)
        }
    }

    /// Executes a single command by invoking the mock handler.
    public func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        try await handler(command, context)
    }

    /// Executes a pipeline by running each stage's command through the handler in order.
    ///
    /// The output from the final stage is returned. Earlier stages are executed but
    /// their output is discarded, mirroring the stdin-chaining semantics of real pipelines.
    public func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
        var lastOutput = ShellOutput(stdout: "", stderr: "", exitCode: 0)
        for stage in pipeline.stages {
            lastOutput = try await handler(stage, context)
        }
        return lastOutput
    }
}
