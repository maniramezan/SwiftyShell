import Foundation
import Testing
@testable import SwiftyShell

private actor InvocationRecorder {
    private var invocations: [String] = []

    func record(_ executable: String) {
        invocations.append(executable)
    }

    func snapshot() -> [String] {
        invocations
    }
}

struct PipelineTests {
    @Test func pipelineDescriptionRendersShellStyleStages() {
        let pipeline = Command("printf", arguments: "alpha\nbeta\n")
            .pipe(to: Command("grep", arguments: "beta"))
            .pipe(to: Command("wc", arguments: "-l"))

        #expect(pipeline.description.contains("printf"))
        #expect(pipeline.description.contains("grep beta"))
        #expect(pipeline.description.contains("wc -l"))
        #expect(pipeline.description.contains(" | "))
    }

    @Test func pipelineDebugDescriptionIncludesStageDebugStrings() {
        let pipeline = Command("echo", arguments: "hello world")
            .pipe(to: Command("grep", arguments: "hello"))

        #expect(pipeline.debugDescription.contains("Pipeline("))
        #expect(pipeline.debugDescription.contains("Command("))
        #expect(pipeline.debugDescription.contains("hello world"))
        #expect(pipeline.debugDescription.contains("grep hello"))
    }

    @Test func mockPipelineStopsOnFirstFailure() async throws {
        let recorder = InvocationRecorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command.executableName)
                if command.executableName == "first" {
                    return ShellOutput(stdout: "", stderr: "boom", exitCode: 9)
                }
                return ShellOutput(stdout: command.executableName, stderr: "", exitCode: 0)
            }
        )

        do {
            _ = try await Command("first")
                .pipe(to: Command("second"))
                .run(in: context)
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(command, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command == "first")
            #expect(output.exitCode == 9)
            #expect(output.stderr == "boom")
            #expect(await recorder.snapshot() == ["first"])
        }
    }

    @Test func pipelineSucceeds() async throws {
        let output = try await Command("printf", arguments: "alpha\nbeta\n")
            .pipe(to: Command("grep", arguments: "beta"))
            .run(in: ShellContext())

        #expect(output.stdout == "beta\n")
    }

    @Test func pipelineFailsOnIntermediateStage() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf 'broken' >&2; exit 9")
                .pipe(to: Command("cat"))
                .run(in: ShellContext())
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(command, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command.contains("/bin/sh"))
            #expect(output.stderr.contains("broken"))
            #expect(output.exitCode == 9)
        }
    }

    @Test func threeStagesPipeline() async throws {
        let output = try await Command("printf", arguments: "alpha\nbeta\ngamma\n")
            .pipe(to: Command("grep", arguments: "-v", "beta"))
            .pipe(to: Command("tr", arguments: "a-z", "A-Z"))
            .run(in: ShellContext())
        #expect(output.stdout == "ALPHA\nGAMMA\n")
    }

    @Test func pipelineExtensionOnPipelineType() async throws {
        let pipeline = Command("printf", arguments: "1\n2\n3\n")
            .pipe(to: Command("grep", arguments: "2"))
        let output =
            try await pipeline
            .pipe(to: Command("cat"))
            .run(in: ShellContext())
        #expect(output.stdout == "2\n")
    }
}
