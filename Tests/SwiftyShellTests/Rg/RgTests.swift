#if Rg
import Foundation
import Testing
@testable import SwiftyShell

struct RgTests {
    @Test func buildsBasicCommand() {
        let command = Rg("TODO").lineNumber().path("Sources").command()
        #expect(command.executableName == "rg")
        #expect(command.arguments == ["-n", "--", "TODO", "Sources"])
    }

    @Test func buildsFixedStringCommand() {
        let command = Rg("hello.world")
            .fixedStrings()
            .ignoreCase()
            .path("/tmp/input.txt")
            .command()
        #expect(command.executableName == "rg")
        #expect(command.arguments == ["-i", "-F", "--", "hello.world", "/tmp/input.txt"])
    }

    @Test func buildsCommandWithMultipleRegexpPatterns() {
        let command = Rg(context: ShellContext())
            .regexp("TODO")
            .regexp("FIXME")
            .path("Sources")
            .command()
        #expect(command.arguments == ["-e", "TODO", "-e", "FIXME", "Sources"])
    }

    @Test func buildsCommandWithPatternFile() {
        let command = Rg(context: ShellContext()).patternFile("patterns.txt").path(".").command()
        #expect(command.arguments == ["-f", "patterns.txt", "."])
    }

    @Test func buildsSearchOptionsCommand() {
        let command = Rg("pattern").smartCase().wordRegexp().maxCount(10).command()
        #expect(command.arguments == ["-S", "-w", "-m", "10", "--", "pattern"])
    }

    @Test func buildsMultilineCommand() {
        let command = Rg("fn.*\\{").multiline().multilineDotAll().command()
        #expect(command.arguments == ["-U", "--multiline-dotall", "--", "fn.*\\{"])
    }

    @Test func buildsPcre2Command() {
        let command = Rg("(?<=fn )\\w+").pcre2().command()
        #expect(command.arguments == ["-P", "--", "(?<=fn )\\w+"])
    }

    @Test func buildsEngineCommand() {
        let command = Rg("pattern").engine(.auto).command()
        #expect(command.arguments == ["--engine", "auto", "--", "pattern"])
    }

    @Test func lastCaseSensitivityCallWins() {
        let command = Rg("pattern").ignoreCase().caseSensitive().command()
        #expect(command.arguments == ["-s", "--", "pattern"])
    }

    @Test func engineClearsPcre2Flag() {
        let command = Rg("pattern").pcre2().engine(.auto).command()
        #expect(command.arguments == ["--engine", "auto", "--", "pattern"])
    }

    @Test func buildsFilterOptionsCommand() {
        let command = Rg("TODO")
            .glob("*.swift")
            .glob("!*.generated.swift")
            .type("swift")
            .typeNot("json")
            .hidden()
            .follow()
            .maxDepth(3)
            .path(".")
            .command()
        #expect(
            command.arguments == [
                "-g", "*.swift", "-g", "!*.generated.swift", "-t", "swift", "-T", "json", "--hidden", "-L", "-d", "3",
                "--", "TODO", ".",
            ]
        )
    }

    @Test func buildsIgnoreOptionsCommand() {
        let command = Rg("pattern").noIgnore().noIgnoreVcs().ignoreFile("/path/.myignore").command()
        #expect(
            command.arguments == [
                "--no-ignore", "--no-ignore-vcs", "--ignore-file", "/path/.myignore", "--", "pattern",
            ]
        )
    }

    @Test func buildsUnrestrictedCommand() {
        let command = Rg("pattern").unrestricted().unrestricted().unrestricted().command()
        #expect(command.arguments == ["-u", "-u", "-u", "--", "pattern"])
    }

    @Test func buildsContextOptionsCommand() {
        let command = Rg("error").afterContext(3).beforeContext(2).command()
        #expect(command.arguments == ["-A", "3", "-B", "2", "--", "error"])
    }

    @Test func buildsCombinedContextCommand() {
        let command = Rg("error").context(5).contextSeparator("===").command()
        #expect(command.arguments == ["-C", "5", "--context-separator", "===", "--", "error"])
    }

    @Test func buildsOutputFormattingCommand() {
        let command = Rg("pattern").color(.never).column().heading().lineNumber().onlyMatching().trim().command()
        #expect(
            command.arguments == ["--color", "never", "--column", "--heading", "-n", "-o", "--trim", "--", "pattern"]
        )
    }

    @Test func buildsReplaceCommand() {
        let command = Rg("(\\w+)@(\\w+)").replace("$1 at $2").command()
        #expect(command.arguments == ["-r", "$1 at $2", "--", "(\\w+)@(\\w+)"])
    }

    @Test func buildsCountCommand() {
        let command = Rg("error").count().includeZero().path("/var/log").command()
        #expect(command.arguments == ["-c", "--include-zero", "--", "error", "/var/log"])
    }

    @Test func buildsFilesWithMatchesCommand() {
        let command = Rg("TODO").filesWithMatches().nullTerminated().path(".").command()
        #expect(command.arguments == ["-l", "-0", "--", "TODO", "."])
    }

    @Test func buildsJsonCommand() {
        let command = Rg("pattern").json().path("src").command()
        #expect(command.arguments == ["--json", "--", "pattern", "src"])
    }

    @Test func buildsVimgrepCommand() {
        let command = Rg("TODO").vimgrep().command()
        #expect(command.arguments == ["--vimgrep", "--", "TODO"])
    }

    @Test func buildsSortCommand() {
        let command = Rg("pattern").sort(.modified).command()
        #expect(command.arguments == ["--sort", "modified", "--", "pattern"])
    }

    @Test func buildsSortReverseCommand() {
        let command = Rg("pattern").sortReverse(.path).command()
        #expect(command.arguments == ["--sortr", "path", "--", "pattern"])
    }

    @Test func buildsSpecialModesCommand() {
        let command = Rg(context: ShellContext()).listFiles().noConfig().path("src").command()
        #expect(command.arguments == ["--files", "--no-config", "src"])
    }

    @Test func buildsTypeListCommand() {
        let command = Rg(context: ShellContext()).typeList().command()
        #expect(command.arguments == ["--type-list"])
    }

    @Test func buildsMaxColumnsCommand() {
        let command = Rg("pattern").maxColumns(120).maxColumnsPreview().command()
        #expect(command.arguments == ["-M", "120", "--max-columns-preview", "--", "pattern"])
    }

    @Test func buildsEncodingCommand() {
        let command = Rg("pattern").encoding("latin1").command()
        #expect(command.arguments == ["-E", "latin1", "--", "pattern"])
    }

    @Test func buildsColorSpecsCommand() {
        let command = Rg("pattern").color(.always).colors("match:fg:red").colors("path:fg:blue").command()
        #expect(
            command.arguments == [
                "--color", "always", "--colors", "match:fg:red", "--colors", "path:fg:blue", "--", "pattern",
            ]
        )
    }

    @Test func buildsPreprocessorCommand() {
        let command = Rg("text").pre("my-preprocessor").preGlob("*.pdf").preGlob("*.docx").command()
        #expect(
            command.arguments == [
                "--pre", "my-preprocessor", "--pre-glob", "*.pdf", "--pre-glob", "*.docx", "--", "text",
            ]
        )
    }

    @Test func buildsTypeAddCommand() {
        let command = Rg("pattern").typeAdd("web:*.html").typeAdd("web:*.css").type("web").command()
        #expect(
            command.arguments == ["--type-add", "web:*.html", "--type-add", "web:*.css", "-t", "web", "--", "pattern"]
        )
    }

    @Test func buildsDebugAndStatsCommand() {
        let command = Rg("pattern").stats().debug().command()
        #expect(command.arguments == ["--stats", "--debug", "--", "pattern"])
    }

    @Test func buildsBufferingCommand() {
        let command = Rg("pattern").lineBuffered().command()
        #expect(command.arguments == ["--line-buffered", "--", "pattern"])
    }

    @Test func buildsIglobCommand() {
        let command = Rg("pattern").iglob("*.TXT").command()
        #expect(command.arguments == ["--iglob", "*.TXT", "--", "pattern"])
    }

    @Test func buildsMaxFilesizeCommand() {
        let command = Rg("pattern").maxFilesize("1M").command()
        #expect(command.arguments == ["--max-filesize", "1M", "--", "pattern"])
    }

    @Test func buildsSearchZipCommand() {
        let command = Rg("pattern").searchZip().command()
        #expect(command.arguments == ["-z", "--", "pattern"])
    }

    @Test func buildsMultiplePathsCommand() {
        let command = Rg("pattern").path("src").path("tests").paths(["docs", "scripts"]).command()
        #expect(command.arguments == ["--", "pattern", "src", "tests", "docs", "scripts"])
    }

    @Test func buildsNoPatternWithRegexpOnly() {
        let command = Rg(context: ShellContext()).regexp("TODO").path(".").command()
        #expect(command.arguments == ["-e", "TODO", "."])
    }

    @Test func buildsByteOffsetCommand() {
        let command = Rg("pattern").byteOffset().command()
        #expect(command.arguments == ["-b", "--", "pattern"])
    }

    @Test func buildsCrlfCommand() {
        let command = Rg("pattern$").crlf().command()
        #expect(command.arguments == ["--crlf", "--", "pattern$"])
    }

    @Test func buildsNoFilenameCommand() {
        let command = Rg("pattern").noFilename().command()
        #expect(command.arguments == ["-I", "--", "pattern"])
    }

    @Test func noLineNumberOverridesLineNumber() {
        let command = Rg("pattern").lineNumber().noLineNumber().command()
        #expect(command.arguments == ["-N", "--", "pattern"])
    }

    @Test func noFilenameOverridesWithFilename() {
        let command = Rg("pattern").withFilename().noFilename().command()
        #expect(command.arguments == ["-I", "--", "pattern"])
    }

    @Test func sortReverseClearsForwardSort() {
        let command = Rg("pattern").sort(.modified).sortReverse(.path).command()
        #expect(command.arguments == ["--sortr", "path", "--", "pattern"])
    }

    @Test func regexpClearsPositionalPattern() {
        let command = Rg("pattern").regexp("override").path("Sources").command()
        #expect(command.arguments == ["-e", "override", "Sources"])
    }

    @Test func patternFileClearsPositionalPattern() {
        let command = Rg("pattern").patternFile("patterns.txt").path("Sources").command()
        #expect(command.arguments == ["-f", "patterns.txt", "Sources"])
    }

    @Test func listFilesClearsSearchPatterns() {
        let command = Rg("pattern").regexp("override").listFiles().path("Sources").command()
        #expect(command.arguments == ["--files", "Sources"])
    }

    @Test func typeListClearsPatternAndPaths() {
        let command = Rg("pattern").path("Sources").typeList().command()
        #expect(command.arguments == ["--type-list"])
    }

    @Test func buildsPassthruCommand() {
        let command = Rg("pattern").passthru().command()
        #expect(command.arguments == ["--passthru", "--", "pattern"])
    }

    @Test func buildsQuietCommand() {
        let command = Rg("pattern").quiet().command()
        #expect(command.arguments == ["-q", "--", "pattern"])
    }

    @Test func buildsThreadsCommand() {
        let command = Rg("pattern").threads(4).command()
        #expect(command.arguments == ["-j", "4", "--", "pattern"])
    }

    @Test func buildsInvertMatchCommand() {
        let command = Rg("skip-this").invertMatch().command()
        #expect(command.arguments == ["-v", "--", "skip-this"])
    }

    @Test func buildsLineRegexpCommand() {
        let command = Rg("exact line").lineRegexp().command()
        #expect(command.arguments == ["-x", "--", "exact line"])
    }

    @Test func runsBasicSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "alpha\nbeta\ngamma\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("beta").noConfig().path(fileURL.path).run()
        #expect(output.stdout.contains("beta"))
        #expect(output.exitCode == 0)
    }

    @Test func runsFixedStringSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "hello.world\nhello world\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("hello.world").fixedStrings().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "hello.world\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsCaseSensitiveSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "Hello\nhello\nHELLO\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("hello").fixedStrings().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "hello\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsIgnoreCaseSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "Hello\nhello\nHELLO\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("hello").fixedStrings().ignoreCase().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "Hello\nhello\nHELLO\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsCountSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "alpha\nbeta\nalpha\ngamma\nalpha\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("alpha").fixedStrings().count().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "3")
        #expect(output.exitCode == 0)
    }

    @Test func runsInvertMatchSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "alpha\nbeta\ngamma\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("beta").fixedStrings().invertMatch().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "alpha\ngamma\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsRecursiveSearch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        let subdir = directory.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "hello world".write(to: subdir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let output = try await Rg("hello").fixedStrings().noConfig().path(directory.path).run()
        #expect(output.stdout.contains("hello world"))
        #expect(output.exitCode == 0)
    }

    @Test func runsSearchInPipeline() async throws {
        let output = try await Command("printf", arguments: "alpha\nbeta42\ngamma\n")
            .pipe(to: Rg(#"beta[0-9]+"#).noConfig().noFilename().command())
            .run(in: ShellContext())
        #expect(output.stdout == "beta42\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsWordRegexpSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "cat\ncatch\nscatter\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("cat").fixedStrings().wordRegexp().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "cat\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsMaxCountSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "match\nmatch\nmatch\nmatch\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("match").fixedStrings().maxCount(2).noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "match\nmatch\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsGlobFilter() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "needle".write(to: directory.appendingPathComponent("file.swift"), atomically: true, encoding: .utf8)
        try "needle".write(to: directory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        let output = try await Rg("needle").fixedStrings().glob("*.swift").noConfig().path(directory.path).run()
        #expect(output.stdout.contains("needle"))
        #expect(!output.stdout.contains("file.txt"))
        #expect(output.exitCode == 0)
    }

    @Test func runsFilesWithMatchesSearch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "needle here".write(to: directory.appendingPathComponent("has-it.txt"), atomically: true, encoding: .utf8)
        try "nothing here".write(
            to: directory.appendingPathComponent("no-match.txt"),
            atomically: true,
            encoding: .utf8
        )
        let output = try await Rg("needle").fixedStrings().filesWithMatches().noConfig().path(directory.path).run()
        #expect(output.stdout.contains("has-it.txt"))
        #expect(!output.stdout.contains("no-match.txt"))
        #expect(output.exitCode == 0)
    }

    @Test func runsOnlyMatchingSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "foo123bar456\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("[0-9]+").onlyMatching().noConfig().noFilename().path(fileURL.path).run()
        #expect(output.stdout == "123\n456\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsReplaceSearch() async throws {
        let fileURL = try makeTemporaryFile(contents: "hello world\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        let output = try await Rg("world").fixedStrings().replace("swift").noConfig().noFilename().path(fileURL.path)
            .run()
        #expect(output.stdout == "hello swift\n")
        #expect(output.exitCode == 0)
    }

    private func makeTemporaryFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("input.txt")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
#endif
