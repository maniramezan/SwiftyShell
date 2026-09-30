import Foundation

public extension Command {
    /// Starts a process in a new session so it can outlive this application.
    ///
    /// Use this for independently owned tools such as Android emulators. The caller owns their
    /// eventual shutdown. Output defaults to discard; use `.file` to keep a log that continues
    /// after the launcher exits. No live streams or exit result are returned.
    ///
    /// ```swift
    /// let pid = try await Command("emulator", arguments: "-avd", "Pixel")
    ///     .stdout(.file(path: "/tmp/emulator.log", append: true))
    ///     .stderr(.file(path: "/tmp/emulator.log", append: true))
    ///     .spawnDetached()
    /// ```
    ///
    /// Stdin must be empty or a file. Tee/log output, timeouts (including context defaults), and
    /// nonzero output limits are rejected. Caller cancellation is checked before scheduling launch;
    /// once scheduled, launch proceeds independently of caller cancellation. The built-in executor reaps the
    /// child while the application remains alive; the OS takes ownership after application exit.
    ///
    /// - Parameter context: The executor and execution defaults.
    /// - Returns: The PID, which is also the new session and process-group identifier.
    /// - Throws: ``ShellError`` for invalid configuration or process-launch failure, or
    ///   `CancellationError` if the calling task is already cancelled.
    func spawnDetached(in context: ShellContext = .init()) async throws -> Int32 {
        try Task.checkCancellation()
        return try await context.executor.spawnDetached(try detachedCommand(in: context), in: context)
    }
}

extension Command {
    func detachedCommand(in context: ShellContext) throws -> Command {
        guard timeoutOverride == nil, context.defaultTimeout == nil,
            (outputLimitOverride ?? context.defaultOutputLimit) == 0
        else {
            throw ShellError.invalidConfiguration(
                description: "Detached processes cannot enforce timeouts or output limits"
            )
        }
        switch stdinSource {
        case .none, .file: break
        case .string, .data:
            throw ShellError.invalidConfiguration(description: "Detached stdin must be empty or a file")
        }
        func output(_ destination: OutputDestination) throws -> OutputDestination {
            switch destination {
            case .capture, .discard: return .discard
            case .file: return destination
            case .tee, .teeTo, .log:
                throw ShellError.invalidConfiguration(
                    description: "Detached output must be discarded or written to a file"
                )
            }
        }
        return try stdout(output(stdoutDestination)).stderr(output(stderrDestination))
    }
}

public extension RunnableCommandFamily {
    /// Starts the built command in a new session that can outlive the calling application.
    ///
    /// See ``Command/spawnDetached(in:)`` for supported input, output, and lifetime behavior.
    /// - Returns: The PID, also the new process-group identifier.
    /// - Throws: ``ShellError`` for invalid configuration or launch failure.
    func spawnDetached() async throws -> Int32 {
        try await command().spawnDetached(in: context)
    }
}
