#if Mkdir
import Foundation
import Testing
@testable import SwiftyShell

struct MkdirCommandTests {
    @Test func buildsMkdirCommand() {
        let command = Mkdir()
            .parents()
            .mode(.octal(0o755))
            .directory("/tmp/example")
            .command()

        #expect(command.executableName == "mkdir")
        #expect(command.arguments == ["-p", "-m", "755", "--", "/tmp/example"])
    }

    @Test func acceptsRawModeString() {
        let command = Mkdir()
            .mode("u=rwx,go=rx")
            .directory("/tmp/example")
            .command()

        #expect(command.arguments == ["-m", "u=rwx,go=rx", "--", "/tmp/example"])
    }

    @Test func createsDirectories() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let nested = directory.appendingPathComponent("a/b/c", isDirectory: true)
        let output = try await Mkdir()
            .parents()
            .directory(nested.path)
            .run()

        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: nested.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(output.exitCode == 0)
    }
}
#endif
