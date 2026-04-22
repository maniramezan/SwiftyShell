import Foundation
import Testing
@testable import SwiftyShell

struct CommandFamilyTests {
    @Test func protocolDefaultsApplySharedConfigurationAndOutputRedirection() {
        let command = DemoCommand()
            .workingDirectory("/tmp")
            .timeout(3)
            .outputLimit(2048)
            .env("MODE", "test")
            .stdout(.discard)
            .stderr(.file(path: "/tmp/demo.err", append: true))
            .verbose()
            .item("value")
            .command()

        #expect(command.executableName == "printf")
        #expect(command.arguments == ["--verbose", "value"])
        #expect(command.workingDirectoryOverride == "/tmp")
        #expect(command.timeoutOverride == 3)
        #expect(command.outputLimitOverride == 2048)
        #expect(command.environmentOverrides["MODE"] == "test")
        #expect(command.stdoutDestination == .discard)
        #expect(command.stderrDestination == .file(path: "/tmp/demo.err", append: true))
    }

    @Test func runnableCommandFamilyInheritsRunImplementation() async throws {
        let output = try await DemoCommand()
            .item("hello")
            .run()

        #expect(output.stdout == "hello")
        #expect(output.exitCode == 0)
    }
}

private struct DemoCommand: RunnableCommandFamily {
    private let state: State

    var context: ShellContext { state.config.context }

    init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    func verbose(_ enabled: Bool = true) -> Self {
        copy(isVerbose: enabled)
    }

    func item(_ value: String) -> Self {
        copy(arguments: state.arguments + [value])
    }

    func command() -> Command {
        var arguments: [String] = []
        if state.isVerbose {
            arguments.append("--verbose")
        }
        arguments.append(contentsOf: state.arguments)

        let base = Command("printf")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isVerbose: Bool? = nil,
        arguments: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                isVerbose: isVerbose ?? state.isVerbose,
                arguments: arguments ?? state.arguments
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isVerbose: Bool
    let arguments: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isVerbose: Bool = false,
        arguments: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isVerbose = isVerbose
        self.arguments = arguments
    }
}
