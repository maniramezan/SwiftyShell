import Foundation
import Testing
@testable import SwiftyShell

struct XcodeBuildTests {
    @Test func buildsTypedCommandWithTrailingArgumentsAndSettings() {
        let command = XcodeBuild()
            .option(.project("App.xcodeproj"))
            .option(.scheme("App"))
            .option(.sdk("iphonesimulator"))
            .buildSetting("SWIFT_VERSION", "6.1")
            .trailingArgument("build")
            .command()

        #expect(command.executableName == "xcodebuild")
        #expect(command.arguments == [
            "-project", "App.xcodeproj",
            "-scheme", "App",
            "-sdk", "iphonesimulator",
            "SWIFT_VERSION=6.1",
            "build"
        ])
    }

    @Test func supportsRecursiveCreateXCFrameworkOptions() {
        let command = XcodeBuild()
            .option(.createXCFramework)
            .option(.framework("/tmp/Foo.framework"))
            .option(.debugSymbols("/tmp/Foo.framework.dSYM"))
            .option(.output("/tmp/Foo.xcframework"))
            .option(.allowInternalDistribution)
            .command()

        #expect(command.arguments == [
            "-create-xcframework",
            "-framework", "/tmp/Foo.framework",
            "-debug-symbols", "/tmp/Foo.framework.dSYM",
            "-output", "/tmp/Foo.xcframework",
            "-allow-internal-distribution"
        ])
    }

    @Test func runsVersionCommand() async throws {
        let output = try await XcodeBuild()
            .option(.version)
            .run()

        #expect(output.stdout.contains("Xcode "))
        #expect(output.stdout.contains("Build version "))
        #expect(output.exitCode == 0)
    }
}
