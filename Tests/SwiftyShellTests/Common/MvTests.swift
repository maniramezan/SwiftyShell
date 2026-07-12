#if Mv
import Foundation
import Testing
@testable import SwiftyShell

struct MvCommandTests {
    @Test func buildsMvCommand() {
        let command = Mv()
            .force()
            .source("from")
            .destination("to")
            .command()

        #expect(command.executableName == "mv")
        #expect(command.arguments == ["-f", "--", "from", "to"])
    }

    @Test func movesFile() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("before.txt")
        let destination = directory.appendingPathComponent("after.txt")
        try "rename me".write(to: source, atomically: true, encoding: .utf8)

        let output = try await Mv()
            .source(source.path)
            .destination(destination.path)
            .run()

        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(output.exitCode == 0)
    }
}
#endif
