import Foundation
import Testing
@testable import SwiftyShell

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
            #expect(description == "Output limit must be greater than or equal to zero bytes")
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
}
