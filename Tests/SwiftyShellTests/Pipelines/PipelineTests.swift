import Foundation
import Testing
@testable import SwiftyShell

struct PipelineTests {
    @Test func pipelineSucceeds() async throws {
        let output = try await Command("printf", "alpha\nbeta\n")
            .pipe(to: Command("grep", "beta"))
            .run(in: ShellContext())

        #expect(output.stdout == "beta\n")
    }

    @Test func pipelineFailsOnIntermediateStage() async throws {
        do {
            _ = try await Command("/bin/sh", "-c", "printf 'broken' >&2; exit 9")
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
        let output = try await Command("printf", "alpha\nbeta\ngamma\n")
            .pipe(to: Command("grep", "-v", "beta"))
            .pipe(to: Command("tr", "a-z", "A-Z"))
            .run(in: ShellContext())
        #expect(output.stdout == "ALPHA\nGAMMA\n")
    }

    @Test func pipelineExtensionOnPipelineType() async throws {
        let pipeline = Command("printf", "1\n2\n3\n")
            .pipe(to: Command("grep", "2"))
        let output = try await pipeline
            .pipe(to: Command("cat"))
            .run(in: ShellContext())
        #expect(output.stdout == "2\n")
    }
}
