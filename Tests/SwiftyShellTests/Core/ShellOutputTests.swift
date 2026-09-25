import Foundation
import Testing
@testable import SwiftyShell

struct ShellOutputTests {
    private static let binary = Data([0xFF, 0xFE, 0x00, 0x01, 0x80])

    @Test func textInitializerStoresUTF8Bytes() {
        let output = ShellOutput(stdout: "héllo", stderr: "warn", exitCode: 0)

        #expect(output.stdoutData == Data("héllo".utf8))
        #expect(output.stderrData == Data("warn".utf8))
    }

    @Test func textViewsDecodeInvalidBytesLossily() {
        let output = ShellOutput(stdoutData: Data([0x61, 0xFF, 0x62]), stderrData: Data([0xC3]), exitCode: 0)

        #expect(output.stdout == "a\u{FFFD}b")
        #expect(output.stderr == "\u{FFFD}")
    }

    @Test func settingTextReplacesBytes() {
        var output = ShellOutput(stdoutData: Self.binary, exitCode: 0)
        output.stdout = "text"
        output.stderr = "err"

        #expect(output.stdoutData == Data("text".utf8))
        #expect(output.stderrData == Data("err".utf8))
    }

    @Test func equalityComparesBytes() {
        #expect(ShellOutput(stdout: "a", exitCode: 0) == ShellOutput(stdoutData: Data("a".utf8), exitCode: 0))
        #expect(
            ShellOutput(stdoutData: Data([0xFF]), exitCode: 0) != ShellOutput(stdoutData: Data([0xFE]), exitCode: 0)
        )
    }

    @Test func validatedTextDecodesEachStreamStrictly() {
        let output = ShellOutput(stdoutData: Data("ok".utf8), stderrData: Data([0xFF]), exitCode: 0)

        #expect(output.validatedText() == "ok")
        #expect(output.validatedText(.stdout) == "ok")
        #expect(output.validatedText(.stderr) == nil)
    }

    @Test func validatedStdoutRejectsInvalidUTF8() throws {
        let command = Command("tool")

        #expect(try ShellOutput(stdout: "ok", exitCode: 0).validatedStdout(for: command) == "ok")
        #expect {
            try ShellOutput(stdoutData: Self.binary, exitCode: 0).validatedStdout(for: command)
        } throws: { error in
            guard case let .decodingError(command, stream) = error as? ShellError else { return false }
            return command.displayString == "tool" && stream == .stdout
        }
    }

    @Test func runCapturesBinaryStdout() async throws {
        let output = try await Command("printf", arguments: "\\377\\376\\000\\001\\200").run()

        #expect(output.stdoutData == Self.binary)
    }

    @Test func runCapturesBinaryStderr() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "printf '\\377\\000' >&2").run()

        #expect(output.stderrData == Data([0xFF, 0x00]))
    }

    @Test func pipelineCapturesBinaryStdout() async throws {
        let output = try await Command("printf", arguments: "\\377\\376\\000\\001\\200")
            .pipe(to: Command("cat"))
            .run()

        #expect(output.stdoutData == Self.binary)
    }

    @Test func exitFailureKeepsBinaryOutput() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf '\\377'; exit 3").run()
            Issue.record("Expected exitFailure")
        } catch let ShellError.exitFailure(_, output) {
            #expect(output.stdoutData == Data([0xFF]))
            #expect(output.exitCode == 3)
        }
    }
}
