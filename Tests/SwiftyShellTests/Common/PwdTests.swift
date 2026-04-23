#if Pwd
import Foundation
import Testing
@testable import SwiftyShell

struct PwdCommandTests {
    @Test func buildsPwdCommand() {
        let command = Pwd()
            .physical()
            .command()

        #expect(command.executableName == "pwd")
        #expect(command.arguments == ["-P"])
    }

    @Test func printsWorkingDirectory() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

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
