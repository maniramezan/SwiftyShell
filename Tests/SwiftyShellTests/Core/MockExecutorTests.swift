import Foundation
import Testing
@testable import SwiftyShell

struct MockExecutorTests {
    // MARK: Recording

    @Test func recordsCommandsInOrder() async throws {
        let mock = MockExecutor(stdout: "ok")
        let context = ShellContext(executor: mock)

        _ = try await Command("git", arguments: "status").run(in: context)
        _ = try await Command("swift", arguments: "build").env("CI", "1").run(in: context)

        #expect(mock.recordedCommands.map(\.executableName) == ["git", "swift"])
        #expect(mock.recordedCommands.last?.environmentOverrides == ["CI": "1"])
    }

    @Test func recordsPipelineStagesAndSpawnedCommands() async throws {
        let mock = MockExecutor()
        let context = ShellContext(executor: mock)

        _ = try await Command("ls").pipe(to: Command("grep", arguments: "x")).run(in: context)
        let process = try await Command("server").spawn(in: context)
        _ = await process.waitForExit()

        #expect(mock.recordedCommands.map(\.executableName) == ["ls", "grep", "server"])
    }

    @Test func copiesShareOneLog() async throws {
        let mock = MockExecutor()
        let copy = mock

        _ = try await Command("echo").run(in: ShellContext(executor: copy))

        #expect(mock.recordedCommands.count == 1)
    }

    @Test func doesNotRecordCommandsRejectedByValidation() async throws {
        let mock = MockExecutor()

        await #expect(throws: ShellError.self) {
            try await Command("echo").outputLimit(-1).run(in: ShellContext(executor: mock))
        }
        #expect(mock.recordedCommands.isEmpty)
    }

    @Test func recordsConcurrentCommands() async throws {
        let mock = MockExecutor()
        let context = ShellContext(executor: mock)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask { _ = try await Command("tool", arguments: "\(index)").run(in: context) }
            }
            try await group.waitForAll()
        }

        #expect(Set(mock.recordedCommands.flatMap(\.arguments)) == Set((0..<50).map(String.init)))
    }

    // MARK: Stubs

    @Test func stubsMatchExecutableAndArgumentsInOrder() async throws {
        let mock = MockExecutor(stubs: [
            .init("git", arguments: ["rev-parse", "HEAD"], returning: ShellOutput(stdout: "abc\n", exitCode: 0)),
            .init("git", returning: ShellOutput(stdout: "any git\n", exitCode: 0)),
        ])
        let context = ShellContext(executor: mock)

        #expect(try await Command("git", arguments: "rev-parse", "HEAD").run(in: context).stdout == "abc\n")
        #expect(try await Command("git", arguments: "status").run(in: context).stdout == "any git\n")
    }

    @Test func predicateStubsMatchArbitraryCommands() async throws {
        let mock = MockExecutor(stubs: [
            .init(
                matching: { $0.workingDirectoryOverride == "/repo" },
                returning: ShellOutput(stdout: "repo", exitCode: 0)
            )
        ])

        let output = try await Command("pwd").workingDirectory("/repo").run(in: ShellContext(executor: mock))

        #expect(output.stdout == "repo")
    }

    @Test func unmatchedCommandThrowsCommandNotFoundWithoutFallback() async throws {
        let mock = MockExecutor(stubs: [.init("git", returning: ShellOutput(exitCode: 0))])

        await #expect {
            try await Command("npm", arguments: "ci").run(in: ShellContext(executor: mock))
        } throws: { error in
            guard case let .commandNotFound(executable) = error as? ShellError else { return false }
            return executable == "npm"
        }
    }

    @Test func unmatchedCommandUsesFallback() async throws {
        let mock = MockExecutor(stubs: [], fallback: ShellOutput(stdout: "fallback", exitCode: 0))

        #expect(try await Command("anything").run(in: ShellContext(executor: mock)).stdout == "fallback")
    }

    @Test func stubWithNonZeroExitThrowsExitFailure() async throws {
        let mock = MockExecutor(stubs: [.init("git", returning: ShellOutput(stderr: "fatal", exitCode: 128))])

        await #expect {
            try await Command("git", arguments: "status").run(in: ShellContext(executor: mock))
        } throws: { error in
            guard case let .exitFailure(_, output) = error as? ShellError else { return false }
            return output.exitCode == 128 && output.stderr == "fatal"
        }
    }

    // MARK: Pipeline semantics

    @Test func pipelineCombinesStderrFromEveryStageInOrder() async throws {
        let mock = MockExecutor { command, _ in
            ShellOutput(stdout: "\(command.executableName)-out", stderr: "\(command.executableName)-err;", exitCode: 0)
        }

        let output = try await Command("a").pipe(to: Command("b")).pipe(to: Command("c"))
            .run(in: ShellContext(executor: mock))

        #expect(output.stdout == "c-out")
        #expect(output.stderr == "a-err;b-err;c-err;")
    }

    @Test func pipelineValidatesEveryStageBeforeRunningAny() async throws {
        let mock = MockExecutor()

        await #expect(throws: ShellError.self) {
            try await Command("first").pipe(to: Command("second").outputLimit(-1))
                .run(in: ShellContext(executor: mock))
        }
        #expect(mock.recordedCommands.isEmpty)
    }

    @Test func pipelineToleratesUpstreamBrokenPipeLikeProduction() async throws {
        let mock = MockExecutor { command, _ in
            command.executableName == "yes"
                ? ShellOutput(exitCode: 128 + SIGPIPE) : ShellOutput(stdout: "y\n", exitCode: 0)
        }

        let output = try await Command("yes").pipe(to: Command("head", arguments: "-n", "1"))
            .run(in: ShellContext(executor: mock))

        #expect(output.stdout == "y\n")
    }

    @Test func pipelineFailsWhenFinalStageReportsBrokenPipe() async throws {
        let mock = MockExecutor { command, _ in
            ShellOutput(exitCode: command.executableName == "last" ? 128 + SIGPIPE : 0)
        }

        await #expect {
            try await Command("first").pipe(to: Command("last")).run(in: ShellContext(executor: mock))
        } throws: { error in
            guard case let .exitFailure(command, output) = error as? ShellError else { return false }
            return command == "last" && output.exitCode == 128 + SIGPIPE
        }
    }

    @Test func pipelineReportsFirstFailingStageInPipelineOrder() async throws {
        let mock = MockExecutor { command, _ in
            switch command.executableName {
            case "b": ShellOutput(stderr: "b failed", exitCode: 2)
            case "c": ShellOutput(stderr: "c failed", exitCode: 3)
            default: ShellOutput(stdout: "out", exitCode: 0)
            }
        }

        await #expect {
            try await Command("a").pipe(to: Command("b")).pipe(to: Command("c"))
                .run(in: ShellContext(executor: mock))
        } throws: { error in
            guard case let .exitFailure(command, output) = error as? ShellError else { return false }
            return command == "b" && output.exitCode == 2 && output.stderr == "b failedc failed"
        }
    }
}
