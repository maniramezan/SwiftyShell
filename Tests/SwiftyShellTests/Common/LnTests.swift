#if Ln
import Foundation
import Testing
@testable import SwiftyShell

struct LnTests {
    @Test func buildsConfiguredCommand() {
        let command = Ln(source: "target", destination: "link")
            .symbolic()
            .force()
            .executable("/usr/bin/ln")
            .env("LANG", "C")
            .workingDirectory("/tmp")
            .timeout(3)
            .outputLimit(128)
            .stdout(.discard)
            .stderr(.tee)
            .command()

        #expect(command.executableName == "ln")
        #expect(command.arguments == ["-s", "-f", "target", "link"])
        #expect(command.executableOverride == "/usr/bin/ln")
        #expect(command.environmentOverrides == ["LANG": "C"])
        #expect(command.workingDirectoryOverride == "/tmp")
        #expect(command.timeoutOverride == 3)
        #expect(command.outputLimitOverride == 128)
        #expect(command.stdoutDestination == .discard)
        #expect(command.stderrDestination == .tee)
    }

    @Test func createsHardAndSymbolicLinks() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source")
        let hardLink = directory.appendingPathComponent("hard")
        let symbolicLink = directory.appendingPathComponent("symbolic")
        try "value".write(to: source, atomically: true, encoding: .utf8)

        _ = try await Ln(source: source.path, destination: hardLink.path).run()
        _ = try await Ln(source: source.path, destination: symbolicLink.path).symbolic().run()

        #expect(try String(contentsOf: hardLink, encoding: .utf8) == "value")
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: symbolicLink.path) == source.path)
    }
}
#endif
