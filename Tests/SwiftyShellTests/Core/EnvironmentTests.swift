import Foundation
import Testing
@testable import SwiftyShell

struct EnvironmentTests {
    private let context = ShellContext(environment: [
        "PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin", "KEEP": "1", "DROP": "secret",
    ])

    private func childEnvironment(of command: Command) async throws -> [String: String] {
        let output = try await command.run(in: context)
        return Dictionary(
            output.stdout.split(separator: "\n").compactMap { line in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            },
            uniquingKeysWith: { _, last in last }
        )
    }

    @Test func unsetEnvRemovesInheritedVariable() async throws {
        let environment = try await childEnvironment(of: Command("env").unsetEnv("DROP"))

        #expect(environment["DROP"] == nil)
        #expect(environment["KEEP"] == "1")
    }

    @Test func unsetIsDifferentFromEmpty() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", #"echo "${DROP-unset}|${EMPTY-unset}""#)
            .unsetEnv("DROP")
            .env("EMPTY", "")
            .run(in: context)

        #expect(output.stdout == "unset|\n")
    }

    @Test func lastCallWinsBetweenEnvAndUnsetEnv() {
        let unsetAfterSet = Command("tool").env("A", "1").unsetEnv("A")
        #expect(unsetAfterSet.environmentOverrides["A"] == nil)
        #expect(unsetAfterSet.unsetEnvironmentVariables == ["A"])

        let setAfterUnset = Command("tool").unsetEnv("A", "B").env("A", "2").env(["B": "3"])
        #expect(setAfterUnset.environmentOverrides == ["A": "2", "B": "3"])
        #expect(setAfterUnset.unsetEnvironmentVariables.isEmpty)
    }

    @Test func toolConfigurationAppliesUnsetVariables() async throws {
        let command = ToolConfiguration(context: context).env("X", "1").unsetEnv(["DROP", "X"]).apply(
            to: Command("env")
        )

        #expect(command.unsetEnvironmentVariables == ["DROP", "X"])
        let environment = try await childEnvironment(of: command)
        #expect(environment["DROP"] == nil)
        #expect(environment["X"] == nil)
    }

    @Test func commandFamiliesInheritUnsetEnv() {
        struct Env: RunnableCommandFamily {
            var config = ToolConfiguration()
            var context: ShellContext { config.context }
            func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
                Self(config: update(config))
            }
            func settingStdoutDestination(_ destination: OutputDestination) -> Self { self }
            func settingStderrDestination(_ destination: OutputDestination) -> Self { self }
            func command() -> Command { config.apply(to: Command("env")) }
        }

        #expect(
            Env().unsetEnv("GIT_DIR", "GIT_WORK_TREE").command().unsetEnvironmentVariables == [
                "GIT_DIR", "GIT_WORK_TREE",
            ]
        )
    }

    @Test func debugDescriptionListsUnsetVariables() {
        #expect(Command("env").unsetEnv("B", "A").debugDescription.contains(#"unsetEnv: ["A", "B"]"#))
    }
}
