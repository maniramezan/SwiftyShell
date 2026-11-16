import Foundation
import Testing

@testable import SwiftyShell

struct AcceptedExitCodesTests {
    private let exitWithOne = Command("/bin/sh", arguments: "-c", "echo out; exit 1")

    @Test func runThrowsForNonZeroExitByDefault() async {
        await #expect {
            try await exitWithOne.run()
        } throws: { error in
            guard case let .exitFailure(_, output) = error as? ShellError else { return false }
            return output.exitCode == 1
        }
    }

    @Test func runReturnsOutputWithRealExitCodeWhenAccepted() async throws {
        let output = try await exitWithOne.acceptingExitCodes([1]).run()
        #expect(output.exitCode == 1)
        #expect(output.stdout == "out\n")
    }

    @Test func unlistedExitCodeStillThrows() async {
        await #expect {
            try await Command("/bin/sh", arguments: "-c", "exit 2").acceptingExitCodes([1]).run()
        } throws: { error in
            guard case let .exitFailure(_, output) = error as? ShellError else { return false }
            return output.exitCode == 2
        }
    }

    @Test func signalTerminationIsNeverAccepted() async {
        await #expect {
            try await Command("/bin/sh", arguments: "-c", "kill -TERM $$")
                .acceptingExitCodes([128 + 15])
                .run()
        } throws: { error in
            guard case .exitFailure = error as? ShellError else { return false }
            return true
        }
    }

    @Test func laterCallReplacesEarlierSet() {
        let command = Command("tool").acceptingExitCodes([1, 2]).acceptingExitCodes([3])
        #expect(command.acceptedExitCodes == [3])
        #expect(command.debugDescription.contains("acceptedExitCodes: [3]"))
    }

    @Test func pipelineAcceptsExitCodePerStage() async throws {
        let pipeline = Command("/bin/sh", arguments: "-c", "echo data; exit 1")
            .acceptingExitCodes([1])
            .pipe(to: Command("cat"))
        let output = try await pipeline.run()
        #expect(output.stdout == "data\n")
        #expect(output.exitCode == 0)
    }

    @Test func pipelineFinalStageKeepsRealExitCode() async throws {
        let pipeline = Command("echo", arguments: "x")
            .pipe(to: Command("/bin/sh", arguments: "-c", "cat >/dev/null; exit 1").acceptingExitCodes([1]))
        let output = try await pipeline.run()
        #expect(output.exitCode == 1)
    }

    @Test func pipelineStillFailsWhenCodeIsNotAcceptedOnThatStage() async {
        let pipeline = Command("/bin/sh", arguments: "-c", "echo data; exit 1")
            .pipe(to: Command("cat").acceptingExitCodes([1]))
        await #expect {
            try await pipeline.run()
        } throws: { error in
            guard case .exitFailure = error as? ShellError else { return false }
            return true
        }
    }

    @Test func mockHonorsAcceptedExitCodes() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "x", exitCode: 1))
        let output = try await Command("grep").acceptingExitCodes([1]).run(in: context)
        #expect(output.exitCode == 1)

        await #expect(throws: ShellError.self) {
            try await Command("grep").run(in: context)
        }
    }

    @Test func mockPipelineHonorsAcceptedExitCodes() async throws {
        let executor = MockExecutor(handler: { command, _ in
            ShellOutput(stdout: command.executableName, exitCode: command.executableName == "last" ? 1 : 0)
        })
        let context = ShellContext(executor: executor)
        let accepted = Command("first").pipe(to: Command("last").acceptingExitCodes([1]))
        let output = try await accepted.run(in: context)
        #expect(output.exitCode == 1)

        await #expect(throws: ShellError.self) {
            try await Command("first").pipe(to: Command("last")).run(in: context)
        }
    }

    @Test func toolConfigurationAppliesAcceptedExitCodes() {
        let configuration = ToolConfiguration().acceptingExitCodes([1])
        #expect(configuration.acceptedExitCodes == [1])
        #expect(configuration.apply(to: Command("tool")).acceptedExitCodes == [1])
        #expect(ToolConfiguration().apply(to: Command("tool")).acceptedExitCodes.isEmpty)
    }
}
