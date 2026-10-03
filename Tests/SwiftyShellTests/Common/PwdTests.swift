#if Pwd
import Foundation
import TestCommons
import Testing
@testable import SwiftyShell

struct PwdCommandTests {
    @Test func exclusiveModesPreserveOtherSelections() {
        #expect(Pwd().physical().logical().command().arguments == ["-L"])
        #expect(Pwd().logical().physical(false).command().arguments == ["-L"])
        #expect(Pwd().physical().physical(false).command().arguments.isEmpty)
    }

    @Test func buildsPwdCommand() {
        let command = Pwd()
            .physical()
            .command()

        #expect(command.executableName == "pwd")
        #expect(command.arguments == ["-P"])
    }

    @Test func printsWorkingDirectory() async throws {
        let scratch = try TemporaryDirectory()
        defer { try? scratch.remove() }
        let directory = scratch.url

        let output = try await Pwd()
            .workingDirectory(directory.path)
            .run()

        let reportedPath = CommonTestSupport.normalizePath(
            output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let expectedPath = CommonTestSupport.normalizePath(directory.path)

        #expect(reportedPath == expectedPath)
        #expect(output.exitCode == 0)
    }
}
#endif
