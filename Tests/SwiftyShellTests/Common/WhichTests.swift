#if Which
import Testing
@testable import SwiftyShell

struct WhichTests {
    @Test func buildsConfiguredCommand() {
        let command = Which("swift")
            .executable("/usr/bin/which")
            .stdout(.tee)
            .stderr(.discard)
            .command()

        #expect(command.executableName == "which")
        #expect(command.arguments == ["swift"])
        #expect(command.executableOverride == "/usr/bin/which")
        #expect(command.stdoutDestination == .tee)
        #expect(command.stderrDestination == .discard)
    }

    @Test func returnsFoundPath() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "/usr/bin/swift\n"))
        let result = try await Which("swift", context: context).lookup().run()
        #expect(result == .found(path: "/usr/bin/swift"))
    }

    @Test func treatsEmptySuccessfulOutputAsNotFound() async throws {
        let context = ShellContext(executor: MockExecutor())
        let result = try await Which("missing", context: context).lookup().run()
        #expect(result == .notFound)
    }

    @Test func treatsExitOneAsNotFound() async throws {
        let context = ShellContext(executor: MockExecutor(exitCode: 1))
        let result = try await Which("missing", context: context).lookup().run()
        #expect(result == .notFound)
    }

    @Test func preservesOtherFailures() async {
        let context = ShellContext(executor: MockExecutor(stderr: "failure", exitCode: 2))
        do {
            _ = try await Which("broken", context: context).lookup().run()
            Issue.record("Expected exitFailure")
        } catch let ShellError.exitFailure(_, output) {
            #expect(output.exitCode == 2)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
#endif
