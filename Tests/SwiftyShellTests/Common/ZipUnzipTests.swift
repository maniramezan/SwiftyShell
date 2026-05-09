#if Zip && Unzip
import Foundation
import Testing
@testable import SwiftyShell

struct ZipUnzipRoundTripTests {
    @Test func entriesRoundTripThroughRealZipAndUnzip() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstName = "first.txt"
        let secondName = "second.txt"
        try "first contents".write(
            to: directory.appendingPathComponent(firstName),
            atomically: true,
            encoding: .utf8
        )
        try "second contents".write(
            to: directory.appendingPathComponent(secondName),
            atomically: true,
            encoding: .utf8
        )

        let archiveName = "round-trip.zip"
        try await Zip()
            .workingDirectory(directory.path)
            .quiet()
            .archive(archiveName)
            .paths([firstName, secondName])
            .run()

        let archivePath = directory.appendingPathComponent(archiveName).path
        let entries = try await Unzip()
            .archive(archivePath)
            .entries()
            .run()

        #expect(Set(entries.map(\.path)) == Set([firstName, secondName]))
    }
}
#endif
