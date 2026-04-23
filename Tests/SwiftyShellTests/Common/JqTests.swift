#if Jq
import Foundation
import Testing
@testable import SwiftyShell

struct JqCommandTests {
    @Test func buildsJqCommand() {
        let command = Jq(".name")
            .rawOutput()
            .compactOutput()
            .slurp()
            .nullInput()
            .sortKeys()
            .arg("kind", "demo")
            .file("input.json")
            .command()

        #expect(command.executableName == "jq")
        #expect(command.arguments == ["-r", "-c", "-s", "-n", "-S", "--arg", "kind", "demo", ".name", "input.json"])
    }

    @Test func transformsJsonWhenJqIsAvailable() async throws {
        guard (try? await Command("jq", "--version").run(in: ShellContext())) != nil else {
            return
        }

        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("input.json")
        try #"{"name":"SwiftyShell"}"#.write(to: input, atomically: true, encoding: .utf8)

        let output = try await Jq(".name")
            .rawOutput()
            .file(input.path)
            .run()

        #expect(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "SwiftyShell")
        #expect(output.exitCode == 0)
    }
}
#endif
