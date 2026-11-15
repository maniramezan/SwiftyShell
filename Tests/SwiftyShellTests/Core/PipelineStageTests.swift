import Foundation
import Testing

@testable import SwiftyShell

struct PipelineStageTests {
    private func sh(_ script: String) -> Command {
        Command("/bin/sh", arguments: "-c", script)
    }

    @Test func runReportingStagesReturnsEveryExitCodeWithoutThrowing() async throws {
        let result = try await sh("echo data; exit 3").pipe(to: Command("cat")).runReportingStages()
        #expect(result.stageExitCodes == [3, 0])
        #expect(result.output.stdout == "data\n")
        #expect(result.output.exitCode == 0)
        #expect(!result.allStagesSucceeded)
    }

    @Test func runReportingStagesReportsFinalStageFailureToo() async throws {
        let result = try await Command("echo", arguments: "x")
            .pipe(to: sh("cat >/dev/null; exit 1"))
            .runReportingStages()
        #expect(result.stageExitCodes == [0, 1])
        #expect(result.output.exitCode == 1)
    }

    @Test func runReportingStagesSucceedsWhenAllExitZero() async throws {
        let result = try await Command("echo", arguments: "hi").pipe(to: Command("cat")).runReportingStages()
        #expect(result.stageExitCodes == [0, 0])
        #expect(result.allStagesSucceeded)
        #expect(result.output.stdout == "hi\n")
    }

    @Test func runStillFailsOnTheSamePipeline() async {
        await #expect(throws: ShellError.self) {
            try await sh("echo data; exit 3").pipe(to: Command("cat")).run()
        }
    }

    @Test func stageSignalsAreReportedAs128PlusSignal() async throws {
        let result = try await sh("kill -TERM $$").pipe(to: Command("cat")).runReportingStages()
        #expect(result.stageExitCodes[0] == 128 + 15)
    }

    @Test func spawnedPipelineStreamsFinalStdoutAndReportsStages() async throws {
        let pipeline = try await sh("printf 'one\\ntwo\\n'; echo oops >&2; exit 2")
            .pipe(to: Command("cat"))
            .spawn(captureOutput: true)
        var lines: [String] = []
        for await line in pipeline.standardOutputLines { lines.append(line) }
        var errors: [String] = []
        for await line in pipeline.standardErrorLines { errors.append(line) }
        #expect(lines == ["one", "two"])
        #expect(errors == ["oops"])
        #expect(await pipeline.waitForStageExitCodes() == [2, 0])
        #expect(pipeline.stageProcessIdentifiers.count == 2)
        #expect(pipeline.processIdentifier == pipeline.stageProcessIdentifiers[1])
        let output = await pipeline.waitForExit()
        #expect(output.stdout == "one\ntwo\n")
        #expect(output.stderr == "oops\n")
        #expect(output.exitCode == 0)
    }

    @Test func spawnedPipelineDoesNotRetainOutputByDefault() async throws {
        let pipeline = try await Command("echo", arguments: "x").pipe(to: Command("cat")).spawn()
        for await _ in pipeline.standardOutput {}
        let output = await pipeline.waitForExit()
        #expect(output.stdout.isEmpty)
    }

    @Test func teardownStopsEveryStage() async throws {
        let pipeline = try await Command("sleep", arguments: "30")
            .pipe(to: Command("cat"))
            .spawn(teardown: .immediate)
        let output = await pipeline.teardownAndWait()
        #expect(output.exitCode != 0)
        let codes = await pipeline.waitForStageExitCodes()
        #expect(codes.count == 2)
        #expect(codes.allSatisfy { $0 != 0 })
    }

    @Test func signalReachesEveryStage() async throws {
        let pipeline = try await Command("sleep", arguments: "30")
            .pipe(to: Command("cat"))
            .spawn()
        try await pipeline.terminate()
        let codes = await pipeline.waitForStageExitCodes()
        #expect(codes == [128 + 15, 128 + 15])
    }

    @Test func spawnedPipelineRejectsStdinOnLaterStage() async {
        await #expect(throws: ShellError.self) {
            _ = try await Command("echo").pipe(to: Command("cat").stdin(.string("x"))).spawn()
        }
    }

    @Test func firstStageStdinFeedsSpawnedPipeline() async throws {
        let pipeline = try await Command("cat").stdin(.string("fed\n")).pipe(to: Command("cat")).spawn()
        var lines: [String] = []
        for await line in pipeline.standardOutputLines { lines.append(line) }
        #expect(lines == ["fed"])
    }

    @Test func mockReportsStageExitCodes() async throws {
        let executor = MockExecutor(handler: { command, _ in
            ShellOutput(stdout: command.executableName, exitCode: command.executableName == "first" ? 4 : 0)
        })
        let context = ShellContext(executor: executor)
        let result = try await Command("first").pipe(to: Command("second")).runReportingStages(in: context)
        #expect(result.stageExitCodes == [4, 0])
        #expect(result.output.stdout == "second")
        #expect(executor.recordedCommands.count == 2)
    }

    @Test func mockSpawnsPipelines() async throws {
        let executor = MockExecutor(handler: { command, _ in
            ShellOutput(stdout: command.executableName + "\n", stderr: "e\n", exitCode: 0)
        })
        let context = ShellContext(executor: executor)
        let pipeline = try await Command("a").pipe(to: Command("b")).spawn(
            captureOutput: true,
            in: context,
            teardown: .immediate
        )
        guard let mock = pipeline as? MockSpawnedPipeline else {
            Issue.record("Expected MockSpawnedPipeline")
            return
        }
        try await mock.interrupt()
        #expect(await mock.signalHistory == [.interrupt])
        #expect(mock.configuredTeardown == .immediate)
        #expect(await mock.waitForStageExitCodes() == [0, 0])
        #expect(mock.stageProcessIdentifiers == [1, 2])
        let output = await mock.teardownAndWait()
        #expect(output.stdout == "b\n")
        #expect(output.stderr == "e\ne\n")
        #expect(await mock.didTeardown)
        var lines: [String] = []
        for await line in mock.standardOutputLines { lines.append(line) }
        #expect(lines == ["b"])
    }

    @Test func customExecutorsMustOptIn() async {
        struct Minimal: CommandExecutor {
            func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
                ShellOutput(exitCode: 0)
            }
            func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
                ShellOutput(exitCode: 0)
            }
            func spawn(
                _ command: Command,
                in context: ShellContext,
                teardown: TeardownStrategy
            ) async throws -> any SpawnedProcess {
                MockSpawnedProcess()
            }
        }
        let context = ShellContext(executor: Minimal())
        let pipeline = Command("a").pipe(to: Command("b"))
        await #expect(throws: ShellError.self) { try await pipeline.runReportingStages(in: context) }
        await #expect(throws: ShellError.self) { _ = try await pipeline.spawn(in: context) }
    }
}
