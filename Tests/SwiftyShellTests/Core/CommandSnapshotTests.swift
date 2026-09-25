import Foundation
import Testing
@testable import SwiftyShell

struct CommandSnapshotTests {
    @Test func exitFailureKeepsArgvBoundariesAndResolvedExecutable() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "exit 3", "two words")
                .env("SECRET_TOKEN", "hunter2")
                .stdin(.string("private input"))
                .run()
            Issue.record("Expected exitFailure")
        } catch let ShellError.exitFailure(command, output) {
            #expect(command.executableName == "/bin/sh")
            #expect(command.arguments == ["-c", "exit 3", "two words"])
            #expect(command.resolvedExecutable == "/bin/sh")
            #expect(command.displayString == "/bin/sh -c 'exit 3' 'two words'")
            #expect(output.exitCode == 3)
            // Environment values and stdin never reach the error.
            let rendered = "\(command) \(String(reflecting: command))"
            #expect(!rendered.contains("hunter2"))
            #expect(!rendered.contains("private input"))
        }
    }

    @Test func bareExecutableRecordsTheResolvedPath() async throws {
        do {
            _ = try await Command("false").run()
            Issue.record("Expected exitFailure")
        } catch let ShellError.exitFailure(command, _) {
            #expect(command.executableName == "false")
            #expect(command.resolvedExecutable?.hasSuffix("/false") == true)
            #expect(command.displayString == command.resolvedExecutable)
        }
    }

    @Test func stringFactoriesBuildDisplayOnlySnapshots() {
        let error = ShellError.exitFailure(command: "custom tool", output: ShellOutput(exitCode: 1))
        guard case let .exitFailure(command, _) = error else {
            Issue.record("Expected exitFailure")
            return
        }
        #expect(command.displayString == "custom tool")
        #expect(command.executableName == nil)
        #expect(command.arguments == nil)
        #expect(error.errorDescription == "'custom tool' exited with status 1")
    }

    @Test func errorsAreEquatable() {
        let output = ShellOutput(stdout: "x", exitCode: 2)
        let snapshot = CommandSnapshot(Command("tool", arguments: "a"))

        #expect(
            ShellError.exitFailure(command: snapshot, output: output) == .exitFailure(command: snapshot, output: output)
        )
        #expect(
            ShellError.exitFailure(command: snapshot, output: output)
                != .exitFailure(command: snapshot, output: ShellOutput(exitCode: 3))
        )
        #expect(ShellError.commandNotFound("tool") == .commandNotFound("tool"))
    }

    @Test func typedParserDecodingErrorsCarryTheCommand() {
        let output = ShellOutput(stdoutData: Data([0xFF]), exitCode: 0)

        #expect {
            try output.validatedStdout(for: Command("which", arguments: "tool"))
        } throws: { error in
            guard case let .decodingError(command, .stdout) = error as? ShellError else { return false }
            return command.executableName == "which" && command.arguments == ["tool"]
        }
    }
}
