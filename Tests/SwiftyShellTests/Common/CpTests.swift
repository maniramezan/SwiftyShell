#if Cp
import Foundation
import Testing
@testable import SwiftyShell

struct CpCommandTests {
    @Test func buildsCpCommand() {
        let command = Cp()
            .recursive()
            .force()
            .source("src")
            .destination("dst")
            .command()

        #expect(command.executableName == "cp")
        #expect(command.arguments == ["-R", "-f", "--", "src", "dst"])
    }

    @Test func copiesFile() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.txt")
        let destination = directory.appendingPathComponent("destination.txt")
        try "copy me".write(to: source, atomically: true, encoding: .utf8)

        let output = try await Cp()
            .source(source.path)
            .destination(destination.path)
            .run()

        let contents = try String(contentsOf: destination, encoding: .utf8)
        #expect(contents == "copy me")
        #expect(output.exitCode == 0)
    }
}
#endif
