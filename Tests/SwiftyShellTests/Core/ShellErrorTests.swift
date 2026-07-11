import Testing
@testable import SwiftyShell

struct ShellErrorTests {
    private let emptyOutput = ShellOutput(stdout: "", stderr: "", exitCode: 0)

    @Test func invalidConfigurationDescription() {
        let error = ShellError.invalidConfiguration(
            description: "Timeout must be greater than or equal to zero seconds"
        )
        #expect(error.errorDescription == "Timeout must be greater than or equal to zero seconds")
    }

    @Test func commandNotFoundDescription() {
        let error = ShellError.commandNotFound("fakecmd")
        #expect(error.errorDescription == "Command not found: fakecmd")
    }

    @Test func exitFailureDescription() {
        let output = ShellOutput(stdout: "", stderr: "", exitCode: 2)
        let error = ShellError.exitFailure(command: "ls /nope", output: output)
        #expect(error.errorDescription == "'ls /nope' exited with status 2")
    }

    @Test func timeoutDescription() {
        let error = ShellError.timeout(command: "sleep", duration: 5.0, partialOutput: emptyOutput)
        #expect(error.errorDescription == "'sleep' timed out after 5.0 seconds")
    }

    @Test func decodingErrorStdout() {
        let error = ShellError.decodingError(command: "cat", stream: .stdout)
        #expect(error.errorDescription == "Failed to decode stdout output for 'cat' as UTF-8")
    }

    @Test func decodingErrorStderr() {
        let error = ShellError.decodingError(command: "cat", stream: .stderr)
        #expect(error.errorDescription == "Failed to decode stderr output for 'cat' as UTF-8")
    }

    @Test func parsingErrorIncludesReason() {
        let error = ShellError.parsingError(command: "git status", reason: "malformed record")
        #expect(error.errorDescription == "Failed to parse output for 'git status': malformed record")
    }

    @Test func outputLimitExceededDescription() {
        let error = ShellError.outputLimitExceeded(command: "find .", limit: 1024, partialOutput: emptyOutput)
        #expect(error.errorDescription == "'find .' exceeded the output limit of 1024 bytes")
    }

    @Test func canceledDescription() {
        let error = ShellError.canceled(command: "sleep 10", partialOutput: emptyOutput)
        #expect(error.errorDescription == "'sleep 10' was canceled")
    }

    @Test func spawnErrorDescription() {
        let error = ShellError.spawnError(command: "fakecmd", reason: "permission denied")
        #expect(error.errorDescription == "Failed to spawn 'fakecmd': permission denied")
    }

    @Test func workflowConditionFailedDescription() {
        let error = ShellError.workflowConditionFailed(description: "Branch must be main")
        #expect(error.errorDescription == "Branch must be main")
    }

    @Test func streamKindDescription() {
        #expect(StreamKind.stdout.description == "stdout")
        #expect(StreamKind.stderr.description == "stderr")
    }

    @Test func shellOutputIsSuccess() {
        #expect(ShellOutput(stdout: "", stderr: "", exitCode: 0).isSuccess)
        #expect(!ShellOutput(stdout: "", stderr: "", exitCode: 1).isSuccess)
        #expect(!ShellOutput(stdout: "", stderr: "", exitCode: 127).isSuccess)
    }
}
