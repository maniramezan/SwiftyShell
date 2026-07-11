#if Env
import Testing
@testable import SwiftyShell

struct EnvTests {
    @Test func buildsEnvironmentAndSafeInvocation() {
        let command = Env()
            .clean()
            .unset("HOME")
            .set("ZED", "last")
            .set(["ALPHA": "first", "VALUE": "with spaces"])
            .command("printf", arguments: ["%s", "$VALUE; rm -rf /"])
            .stdout(.tee)
            .stderr(.discard)
            .command()

        #expect(
            command.arguments
                == [
                    "-i", "-u", "HOME", "ALPHA=first", "VALUE=with spaces", "ZED=last", "printf", "%s",
                    "$VALUE; rm -rf /",
                ]
        )
        #expect(command.stdoutDestination == .tee)
        #expect(command.stderrDestination == .discard)
    }

    @Test func invokesCommandWithCleanEnvironment() async throws {
        let output = try await Env()
            .clean()
            .set("SWIFTY_SHELL_ENV_TEST", "expected value")
            .command("printenv", arguments: ["SWIFTY_SHELL_ENV_TEST"])
            .run()

        #expect(output.stdout == "expected value\n")
    }

    @Test func printsEnvironmentWhenNoCommandIsConfigured() async throws {
        let output = try await Env().clean().set("ONLY", "value").run()
        #expect(output.stdout == "ONLY=value\n")
    }
}
#endif
