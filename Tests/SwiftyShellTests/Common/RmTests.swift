#if Rm
import Foundation
import Testing
@testable import SwiftyShell

struct RmCommandTests {
    @Test func buildsRmCommand() {
        let command = Rm()
            .recursive()
            .force()
            .path("/tmp/example")
            .command()

        #expect(command.executableName == "rm")
        #expect(command.arguments == ["-r", "-f", "--", "/tmp/example"])
    }

    @Test func removesDirectories() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        let nested = directory.appendingPathComponent("inner", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "gone".write(to: nested.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let output = try await Rm()
            .recursive()
            .path(directory.path)
            .run()

        #expect(!FileManager.default.fileExists(atPath: directory.path))
        #expect(output.exitCode == 0)
    }
}
#endif
