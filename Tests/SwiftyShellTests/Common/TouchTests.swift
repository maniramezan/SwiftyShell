#if Touch
import Foundation
import Testing
@testable import SwiftyShell

struct TouchTests {
    @Test func buildsConfiguredCommand() {
        let command = Touch("one")
            .accessTimeOnly()
            .modificationTimeOnly()
            .noCreate()
            .reference("reference")
            .timestamp("202601020304.05")
            .path("two")
            .paths(["three"])
            .stdout(.discard)
            .stderr(.tee)
            .command()

        #expect(
            command.arguments
                == ["-a", "-m", "-c", "-t", "202601020304.05", "one", "two", "three"]
        )
        #expect(command.stdoutDestination == .discard)
        #expect(command.stderrDestination == .tee)
    }

    @Test func referenceReplacesTimestamp() {
        let command = Touch("file").timestamp("202601020304.05").reference("reference").command()
        #expect(command.arguments == ["-r", "reference", "file"])
    }

    @Test func createsFilesAndHonorsNoCreate() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let created = directory.appendingPathComponent("created")
        let skipped = directory.appendingPathComponent("skipped")

        _ = try await Touch(created.path).run()
        _ = try await Touch(skipped.path).noCreate().run()

        #expect(FileManager.default.fileExists(atPath: created.path))
        #expect(!FileManager.default.fileExists(atPath: skipped.path))
    }
}
#endif
