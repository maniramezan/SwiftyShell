#if Ls
import Foundation
import Testing
@testable import SwiftyShell

struct LsCommandTests {
    @Test func buildsLsCommand() {
        let command = Ls()
            .all()
            .longFormat()
            .humanReadable()
            .recursive()
            .directoryAsFile()
            .path("/tmp")
            .command()

        #expect(command.executableName == "ls")
        #expect(command.arguments == ["-a", "-l", "-h", "-R", "-d", "/tmp"])
    }

    @Test func listsDirectoryContents() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("note.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try await Ls()
            .path(directory.path)
            .run()

        #expect(output.stdout.contains("note.txt"))
        #expect(output.exitCode == 0)
    }
}
#endif
