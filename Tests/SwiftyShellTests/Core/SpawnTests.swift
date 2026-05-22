import Foundation
import Testing
@testable import SwiftyShell

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private struct ProcessExitTimeout: Error {}

private func waitForProcessExit(
    processIdentifier: Int32,
    timeoutNanoseconds: UInt64 = 12_000_000_000
) async throws {
    let pollInterval: UInt64 = 10_000_000
    let attempts = Int(timeoutNanoseconds / pollInterval)

    for _ in 0..<attempts {
        if kill(processIdentifier, 0) == -1, errno == ESRCH {
            return
        }
        try await Task.sleep(nanoseconds: pollInterval)
    }

    Issue.record("Timed out waiting for process exit for pid \(processIdentifier)")
    throw ProcessExitTimeout()
}

struct SpawnTests {
    @Test func mockSpawnReturnsPresetOutputAndStreams() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "ready\n", stderr: "warn\n"))

        let process = try await Command("server", arguments: "--port", "8080")
            .spawn(in: context)

        var stdout = ""
        for await chunk in process.standardOutput {
            stdout += chunk
        }

        var stderr = ""
        for await chunk in process.standardError {
            stderr += chunk
        }

        let output = await process.waitForExit()
        #expect(stdout == "ready\n")
        #expect(stderr == "warn\n")
        #expect(output == ShellOutput(stdout: "ready\n", stderr: "warn\n", exitCode: 0))
    }

    @Test func mockSpawnRecordsSignalsAndTeardown() async throws {
        let context = ShellContext(executor: MockExecutor())

        let process = try await Command("recorder").spawn(in: context, teardown: .interruptThenTerminate)
        guard let mock = process as? MockSpawnedProcess else {
            Issue.record("Expected MockSpawnedProcess")
            return
        }

        try await process.interrupt()
        try await process.terminate()
        _ = await process.teardownAndWait()

        #expect(await mock.signalHistory == [.interrupt, .terminate])
        #expect(await mock.didTeardown)
        #expect(mock.configuredTeardown == .interruptThenTerminate)
    }

    @Test func mockSpawnRejectsInvalidOutputLimit() async throws {
        let context = ShellContext(executor: MockExecutor())

        do {
            _ = try await Command("bad").outputLimit(-1).spawn(in: context)
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Output limit must be zero (unlimited) or a positive byte count")
        }
    }

    @Test func realSpawnStreamsAndWaitsForNaturalExit() async throws {
        let process = try await Command("/bin/sh", arguments: "-c", "printf spawned; printf err >&2")
            .spawn()

        var stdout = ""
        for await chunk in process.standardOutput {
            stdout += chunk
        }

        var stderr = ""
        for await chunk in process.standardError {
            stderr += chunk
        }

        let output = await process.waitForExit()
        #expect(stdout == "spawned")
        #expect(stderr == "err")
        #expect(output == ShellOutput(stdout: "spawned", stderr: "err", exitCode: 0))
    }

    @Test func realSpawnCanBeInterrupted() async throws {
        let process = try await Command("/bin/sh", arguments: "-c", "while true; do sleep 1; done")
            .spawn(teardown: .interruptThenTerminate)

        try await process.terminate()
        let output = await process.waitForExit()
        #expect(output.exitCode == 143)
    }

    @Test func spawnFailsWithCommandNotFound() async throws {
        do {
            _ = try await Command("swiftyshell-spawn-command-that-does-not-exist").spawn()
            Issue.record("Expected commandNotFound")
        } catch let error as ShellError {
            guard case let .commandNotFound(command) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command == "swiftyshell-spawn-command-that-does-not-exist")
        }
    }

    @Test func waitForExitIsIdempotent() async throws {
        let process = try await Command("/bin/sh", arguments: "-c", "printf spawned")
            .spawn()

        let firstOutput = await process.waitForExit()
        let secondOutput = await process.waitForExit()

        #expect(firstOutput == ShellOutput(stdout: "spawned", stderr: "", exitCode: 0))
        #expect(secondOutput == firstOutput)
    }

    @Test func teardownAndWaitStopsLongRunningProcess() async throws {
        let process = try await Command("/bin/sh", arguments: "-c", "while true; do sleep 1; done")
            .spawn(teardown: .graceful)

        let output = await process.teardownAndWait()
        #expect(output.exitCode == 143)
    }

    @Test func droppingSpawnedProcessHandleTriggersBestEffortTeardown() async throws {
        let processIdentifier: Int32

        do {
            var process: (any SpawnedProcess)? = try await Command(
                "/bin/sh",
                arguments: "-c",
                "while true; do sleep 1; done"
            )
            .spawn(teardown: .graceful)
            processIdentifier = try #require(process?.processIdentifier)
            process = nil
            await Task.yield()
        }

        try await waitForProcessExit(processIdentifier: processIdentifier)
    }
}
