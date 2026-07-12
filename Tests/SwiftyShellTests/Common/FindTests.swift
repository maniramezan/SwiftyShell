#if Find
import Foundation
import Testing
@testable import SwiftyShell

struct FindCommandTests {
    @Test func buildsExactArgvForComposedExpression() {
        let expression = FindExpression.name("*.swift")
            .and(.type(.regularFile).or(.path("*/Generated/*").negated()))
            .and(.minimumDepth(1))
            .and(.maximumDepth(4))
            .and(.print0)

        let command = Find()
            .roots(["Sources", "/tmp/special path"])
            .expression(expression)
            .command()

        #expect(command.executableName == "find")
        #expect(
            command.arguments == [
                "Sources", "/tmp/special path", "(", "(", "(", "(", "-name", "*.swift", "-and", "(",
                "-type", "f", "-or", "!", "(", "-path", "*/Generated/*", ")", ")", ")", "-and",
                "-mindepth", "1", ")", "-and", "-maxdepth", "4", ")", "-and", "-print0", ")",
            ]
        )
    }

    @Test func defaultsToExplicitCurrentDirectory() {
        #expect(Find().command().arguments == ["."])
    }

    @Test func qualifiesAmbiguousRelativeRoots() {
        let command = Find()
            .roots(["-cache", "!important", "(draft)", "safe/-child", "./-ready", "/-absolute"])
            .expression(.print)
            .command()

        #expect(
            command.arguments == [
                "./-cache", "./!important", "./(draft)", "safe/-child", "./-ready", "/-absolute", "-print",
            ]
        )
    }

    @Test func findsSpecialPathsWithoutShellInterpretation() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let root = directory.appendingPathComponent("-root with spaces", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("literal $HOME [draft].swift")
        try "test".write(to: file, atomically: true, encoding: .utf8)

        let context = ShellContext(workingDirectory: directory.path)
        let output = try await Find(context: context)
            .root("-root with spaces")
            .expression(.name("literal $HOME [[]draft].swift").and(.type(.regularFile)).and(.print))
            .run()

        #expect(output.stdout == "./-root with spaces/literal $HOME [draft].swift\n")
        #expect(output.exitCode == 0)
    }

    @Test func emitsNullDelimitedOutput() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let file = directory.appendingPathComponent("line\nbreak.txt")
        try "test".write(to: file, atomically: true, encoding: .utf8)

        let output = try await Find()
            .root(directory.path)
            .expression(.name("*.txt").and(.maximumDepth(1)).and(.print0))
            .run()

        #expect(output.stdout.utf8.last == 0)
        #expect(output.stdout.contains("line\nbreak.txt"))
    }
}
#endif
