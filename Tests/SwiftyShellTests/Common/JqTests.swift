#if Jq
import Foundation
import TestCommons
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
        guard (try? await Command("jq", arguments: "--version").run(in: ShellContext())) != nil else {
            return
        }

        let scratch = try TemporaryDirectory()
        defer { try? scratch.remove() }
        let directory = scratch.url

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
