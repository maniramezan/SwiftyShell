import Foundation
import Testing
@testable import SwiftyShell

struct XcrunTests {
    @Test func buildsTypedCommandWithOptionsAndToolArguments() {
        let command = Xcrun()
            .option(.sdk("iphonesimulator"))
            .option(.find)
            .tool("simctl")
            .command()

        #expect(command.executableName == "xcrun")
        #expect(command.arguments == [
            "--sdk", "iphonesimulator",
            "--find",
            "simctl"
        ])
    }

    @Test func buildsSimctlListCommand() {
        let command = Xcrun()
            .simctl()
            .list(.devices, json: true)
            .buildCommand()

        #expect(command.executableName == "xcrun")
        #expect(command.arguments == [
            "simctl",
            "list",
            "devices",
            "--json"
        ])
    }

    @Test func buildsSimctlRuntimeAndIOCommands() {
        let runtime = Simctl()
            .runtime(arguments: ["list"])
            .buildCommand()
        let io = Simctl()
            .io("booted", command: "recordVideo", arguments: ["/tmp/out.mp4"])
            .buildCommand()

        #expect(runtime.arguments == ["simctl", "runtime", "list"])
        #expect(io.arguments == ["simctl", "io", "booted", "recordVideo", "/tmp/out.mp4"])
    }

    @Test func buildsSimctlUpgradeCommand() {
        let command = Simctl()
            .upgrade(["device-uuid-1", "device-uuid-2"])
            .buildCommand()

        #expect(command.arguments == ["simctl", "upgrade", "device-uuid-1", "device-uuid-2"])
    }

    @Test func runsVersionCommand() async throws {
        let output = try await Xcrun()
            .option(.version)
            .run()

        #expect(output.stdout.contains("xcrun version"))
        #expect(output.exitCode == 0)
    }
}
