import Foundation
import Testing
@testable import SwiftyShell

struct BrewTests {
    @Test func defaultsToListSubcommand() {
        let command = Brew().command()

        #expect(command.executableName == "brew")
        #expect(command.arguments == ["list"])
    }

    @Test func buildsInstallCommandWithFormulae() {
        let command = Brew()
            .install("ripgrep", "fzf")
            .command()

        #expect(command.arguments == ["install", "ripgrep", "fzf"])
    }

    @Test func buildsInstallCommandFromArray() {
        let command = Brew()
            .install(["git", "bat"])
            .command()

        #expect(command.arguments == ["install", "git", "bat"])
    }

    @Test func buildsInstallCommandWithCaskFlag() {
        let command = Brew()
            .install("firefox")
            .cask()
            .command()

        #expect(command.arguments == ["install", "--cask", "firefox"])
    }

    @Test func buildsUninstallCommandWithForce() {
        let command = Brew()
            .uninstall("ripgrep")
            .force()
            .command()

        #expect(command.arguments == ["uninstall", "--force", "ripgrep"])
    }

    @Test func buildsUpgradeCommandWithNoFormulae() {
        let command = Brew()
            .upgrade()
            .command()

        #expect(command.arguments == ["upgrade"])
    }

    @Test func buildsUpgradeCommandWithFormulae() {
        let command = Brew()
            .upgrade("swift-format")
            .greedy()
            .command()

        #expect(command.arguments == ["upgrade", "--greedy", "swift-format"])
    }

    @Test func buildsUpdateCommand() {
        let command = Brew().update().command()

        #expect(command.arguments == ["update"])
    }

    @Test func buildsInfoCommand() {
        let command = Brew()
            .info("swiftlint")
            .command()

        #expect(command.arguments == ["info", "swiftlint"])
    }

    @Test func buildsSearchCommand() {
        let command = Brew()
            .search("ripgrep")
            .command()

        #expect(command.arguments == ["search", "ripgrep"])
    }

    @Test func buildsOutdatedCommandWithGreedy() {
        let command = Brew()
            .outdated()
            .greedy()
            .command()

        #expect(command.arguments == ["outdated", "--greedy"])
    }

    @Test func buildsListCommandWithCaskAndVerbose() {
        let command = Brew()
            .list()
            .cask()
            .verbose()
            .command()

        #expect(command.arguments == ["list", "--cask", "--verbose"])
    }

    @Test func buildsInstallCommandWithAllFlags() {
        let command = Brew()
            .install("htop")
            .cask(false)
            .formulaFlag()
            .force()
            .quiet()
            .verbose()
            .dryRun()
            .command()

        #expect(
            command.arguments == [
                "install",
                "--formula",
                "--force",
                "--quiet",
                "--verbose",
                "--dry-run",
                "htop",
            ]
        )
    }

    @Test func formulaAppendsToPositionalArguments() {
        let command = Brew()
            .install("ripgrep")
            .formula("fzf")
            .formulae(["bat", "git"])
            .command()

        #expect(command.arguments == ["install", "ripgrep", "fzf", "bat", "git"])
    }

    @Test func executesBrewInstallThroughMockExecutor() async throws {
        let mock = MockExecutor(stdout: "Installed ripgrep.\n")
        let context = ShellContext(executor: mock)

        let output = try await Brew(context: context)
            .install("ripgrep")
            .run()

        #expect(output.stdout == "Installed ripgrep.\n")
        #expect(output.exitCode == 0)
    }

    @Test func propagatesExitFailureFromMockExecutor() async {
        let mock = MockExecutor(
            stdout: "",
            stderr: "Error: No such keg: /opt/homebrew/Cellar/nonexistent\n",
            exitCode: 1
        )
        let context = ShellContext(executor: mock)

        await #expect(throws: ShellError.self) {
            try await Brew(context: context)
                .uninstall("nonexistent")
                .run()
        }
    }

    @Test func executesRealBrewWhenAvailable() async throws {
        guard (try? await Command("brew", "--version").run(in: ShellContext()))?.isSuccess == true else {
            return
        }

        let output = try await Brew()
            .list()
            .run()

        #expect(output.exitCode == 0)
    }
}
