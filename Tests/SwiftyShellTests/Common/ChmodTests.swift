#if Chmod
import Foundation
import Testing
@testable import SwiftyShell

struct ChmodCommandTests {
    @Test func buildsChmodCommand() {
        let command = Chmod()
            .recursive()
            .mode(.octal(0o755))
            .path("/tmp/example")
            .command()

        #expect(command.executableName == "chmod")
        #expect(command.arguments == ["-R", "755", "/tmp/example"])
    }

    @Test func acceptsRawModeStringAndMultiplePaths() {
        let command = Chmod()
            .mode("u=rw,go=r")
            .paths(["/tmp/a", "/tmp/b"])
            .command()

        #expect(command.arguments == ["u=rw,go=r", "/tmp/a", "/tmp/b"])
    }

    @Test func updatesPermissions() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("example.txt")
        #expect(FileManager.default.createFile(atPath: file.path, contents: Data()))

        let output = try await Chmod()
            .mode(.octal(0o600))
            .path(file.path)
            .run()

        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)

        #expect(permissions.uint16Value == 0o600)
        #expect(output.exitCode == 0)
    }
}
#endif
