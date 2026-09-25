#if Rg
import Foundation

/// The regex engine that `rg` should use.
///
/// Controls whether ripgrep uses its default Rust regex engine, PCRE2 (for look-around and
/// backreferences), or automatic selection. Maps to the `--engine` flag.
public enum RgEngine: String, Sendable, Equatable, Hashable {
    /// The default Rust regex engine. Fastest for most patterns.
    case `default`

    /// The PCRE2 regex engine. Supports look-around and backreferences.
    case pcre2

    /// Automatically choose the engine based on pattern features.
    case auto
}

/// The sort key for ordering ripgrep's output.
///
/// Controls how ripgrep orders files before searching. Maps to the `--sort` and `--sortr` flags.
public enum RgSortKey: String, Sendable, Equatable, Hashable {
    /// Sort by file path.
    case path

    /// Sort by last modification time.
    case modified

    /// Sort by last access time.
    case accessed

    /// Sort by creation time.
    case created

    /// No sorting (default).
    case none
}

/// Controls when ripgrep uses colored output.
///
/// Maps to the `--color` flag.
public enum RgColorWhen: String, Sendable, Equatable, Hashable {
    /// Never use colors.
    case never

    /// Automatically detect whether to use colors based on terminal.
    case auto

    /// Always use colors.
    case always

    /// Use ANSI colors (alias for `always`).
    case ansi
}

/// A fluent wrapper for the `rg` (ripgrep) command.
///
/// ``Rg`` provides comprehensive typed access to ripgrep's search capabilities including
/// regex and literal pattern matching, file type filtering, context lines, output formatting,
/// multiline search, PCRE2 support, and more.
///
/// Use ``init(_:context:)`` for a basic regex search:
///
/// ```swift
/// let result = try await Rg("TODO|FIXME", context: context)
///     .type("swift")
///     .lineNumber()
///     .path("Sources")
///     .run()
///
/// print(result.stdout)
/// ```
///
/// Use ``fixedStrings(_:)`` for literal matching, or ``pcre2(_:)`` for look-around support:
///
/// ```swift
/// let result = try await Rg("hello world", context: context)
///     .fixedStrings()
///     .ignoreCase()
///     .path(".")
///     .run()
/// ```
///
/// Build a ``Command`` with ``command()`` when `rg` should be a pipeline stage:
///
/// ```swift
/// let output = try await Command("cat", arguments: "access.log")
///     .pipe(to: Rg("ERROR").command())
///     .run(in: context)
/// ```
public struct Rg: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an `rg` command family with a positional pattern.
    ///
    /// The pattern is treated as a regex by default. Use ``fixedStrings(_:)`` for literal matching.
    ///
    /// - Parameters:
    ///   - pattern: The regex pattern to search for.
    ///   - context: The shell context whose executor, search paths, environment, and
    ///     defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(_ pattern: String, context: ShellContext = .init()) {
        self.state = State(
            config: ToolConfiguration(context: context),
            positionalPattern: pattern
        )
    }

    /// Creates an `rg` command family without a positional pattern.
    ///
    /// Use this initializer when patterns are supplied via ``regexp(_:)`` or
    /// ``patternFile(_:)``, or when using special modes like ``listFiles(_:)`` or
    /// ``typeList(_:)``.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `rg` command's stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `rg` command's stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    public func regexp(_ pattern: String) -> Self {
        modified(self) {
            $0.state.positionalPattern = nil
            $0.state.regexpPatterns += [pattern]
            $0.state.listsFiles = false
            $0.state.listsTypes = false
        }
    }

    public func patternFile(_ path: String) -> Self {
        modified(self) {
            $0.state.positionalPattern = nil
            $0.state.patternFiles += [path]
            $0.state.listsFiles = false
            $0.state.listsTypes = false
        }
    }

    public func pre(_ command: String) -> Self { modified(self) { $0.state.preCommand = command } }
    public func preGlob(_ glob: String) -> Self { modified(self) { $0.state.preGlobs += [glob] } }
    public func searchZip(_ enabled: Bool = true) -> Self { modified(self) { $0.state.searchesZip = enabled } }

    public func caseSensitive(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.isCaseSensitive = enabled
            if enabled {
                $0.state.isCaseInsensitive = false
                $0.state.isSmartCase = false
            }
        }
    }

    public func ignoreCase(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled { $0.state.isCaseSensitive = false }
            $0.state.isCaseInsensitive = enabled
            if enabled { $0.state.isSmartCase = false }
        }
    }

    public func smartCase(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled {
                $0.state.isCaseSensitive = false
                $0.state.isCaseInsensitive = false
            }
            $0.state.isSmartCase = enabled
        }
    }

    public func fixedStrings(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesFixedStrings = enabled } }
    public func invertMatch(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isInverted = enabled } }
    public func wordRegexp(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isWordRegexp = enabled } }
    public func lineRegexp(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isLineRegexp = enabled } }
    public func maxCount(_ count: Int) -> Self { modified(self) { $0.state.maxCount = count } }
    public func multiline(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isMultiline = enabled } }
    public func multilineDotAll(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isMultilineDotAll = enabled }
    }

    public func pcre2(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.usesPcre2 = enabled
            if enabled { $0.state.engineOverride = nil }
        }
    }

    public func engine(_ engine: RgEngine) -> Self {
        modified(self) {
            $0.state.usesPcre2 = false
            $0.state.engineOverride = engine
        }
    }

    public func encoding(_ encoding: String) -> Self { modified(self) { $0.state.encodingOverride = encoding } }
    public func crlf(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesCrlf = enabled } }
    public func nullData(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesNullData = enabled } }
    public func noUnicode(_ enabled: Bool = true) -> Self { modified(self) { $0.state.disablesUnicode = enabled } }
    public func text(_ enabled: Bool = true) -> Self { modified(self) { $0.state.treatsAsText = enabled } }
    public func stopOnNonmatch(_ enabled: Bool = true) -> Self { modified(self) { $0.state.stopsOnNonmatch = enabled } }
    public func mmap(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.usesMmap = enabled
            if enabled { $0.state.disablesMmap = false }
        }
    }
    public func noMmap(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled { $0.state.usesMmap = false }
            $0.state.disablesMmap = enabled
        }
    }
    public func threads(_ count: Int) -> Self { modified(self) { $0.state.threadCount = count } }
    public func dfaSizeLimit(_ limit: String) -> Self { modified(self) { $0.state.dfaSizeLimitOverride = limit } }
    public func regexSizeLimit(_ limit: String) -> Self { modified(self) { $0.state.regexSizeLimitOverride = limit } }
    public func autoHybridRegex(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesAutoHybridRegex = enabled }
    }
    public func noPcre2Unicode(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesPcre2Unicode = enabled }
    }

    public func glob(_ pattern: String) -> Self { modified(self) { $0.state.globs += [pattern] } }
    public func iglob(_ pattern: String) -> Self { modified(self) { $0.state.iglobs += [pattern] } }
    public func globCaseInsensitive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isGlobCaseInsensitive = enabled }
    }
    public func type(_ fileType: String) -> Self { modified(self) { $0.state.types += [fileType] } }
    public func typeNot(_ fileType: String) -> Self { modified(self) { $0.state.typesNot += [fileType] } }
    public func typeAdd(_ spec: String) -> Self { modified(self) { $0.state.typeAdds += [spec] } }
    public func typeClear(_ fileType: String) -> Self { modified(self) { $0.state.typeClears += [fileType] } }
    public func hidden(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsHidden = enabled } }
    public func follow(_ enabled: Bool = true) -> Self { modified(self) { $0.state.followsSymlinks = enabled } }
    public func maxDepth(_ depth: Int) -> Self { modified(self) { $0.state.maxDepthOverride = depth } }
    public func maxFilesize(_ size: String) -> Self { modified(self) { $0.state.maxFilesizeOverride = size } }
    public func noIgnore(_ enabled: Bool = true) -> Self { modified(self) { $0.state.disablesIgnore = enabled } }
    public func noIgnoreDot(_ enabled: Bool = true) -> Self { modified(self) { $0.state.disablesIgnoreDot = enabled } }
    public func noIgnoreExclude(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesIgnoreExclude = enabled }
    }
    public func noIgnoreParent(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesIgnoreParent = enabled }
    }
    public func noIgnoreGlobal(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesIgnoreGlobal = enabled }
    }
    public func noIgnoreVcs(_ enabled: Bool = true) -> Self { modified(self) { $0.state.disablesIgnoreVcs = enabled } }
    public func noIgnoreFiles(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesIgnoreFiles = enabled }
    }
    public func ignoreFile(_ path: String) -> Self { modified(self) { $0.state.ignoreFiles += [path] } }
    public func ignoreFileCaseInsensitive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isIgnoreFileCaseInsensitive = enabled }
    }
    public func noRequireGit(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.disablesRequireGit = enabled }
    }
    public func oneFileSystem(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesOneFileSystem = enabled }
    }
    public func unrestricted() -> Self { modified(self) { $0.state.unrestrictedLevel += 1 } }
    public func binary(_ enabled: Bool = true) -> Self { modified(self) { $0.state.searchesBinary = enabled } }

    public func afterContext(_ lines: Int) -> Self { modified(self) { $0.state.afterContextLines = lines } }
    public func beforeContext(_ lines: Int) -> Self { modified(self) { $0.state.beforeContextLines = lines } }
    public func context(_ lines: Int) -> Self { modified(self) { $0.state.contextLines = lines } }
    public func contextSeparator(_ separator: String) -> Self {
        modified(self) { $0.state.contextSeparatorOverride = separator }
    }
    public func fieldContextSeparator(_ separator: String) -> Self {
        modified(self) { $0.state.fieldContextSeparatorOverride = separator }
    }
    public func fieldMatchSeparator(_ separator: String) -> Self {
        modified(self) { $0.state.fieldMatchSeparatorOverride = separator }
    }
    public func color(_ when: RgColorWhen) -> Self { modified(self) { $0.state.colorWhen = when } }
    public func colors(_ spec: String) -> Self { modified(self) { $0.state.colorSpecs += [spec] } }
    public func column(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsColumn = enabled } }
    public func heading(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesHeading = enabled } }
    public func lineNumber(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.showsLineNumber = enabled
            if enabled { $0.state.suppressesLineNumber = false }
        }
    }
    public func noLineNumber(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled { $0.state.showsLineNumber = false }
            $0.state.suppressesLineNumber = enabled
        }
    }
    public func maxColumns(_ count: Int) -> Self { modified(self) { $0.state.maxColumnsOverride = count } }
    public func maxColumnsPreview(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.showsMaxColumnsPreview = enabled }
    }
    public func onlyMatching(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsOnlyMatching = enabled } }
    public func replace(_ text: String) -> Self { modified(self) { $0.state.replacementText = text } }
    public func passthru(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesPassthru = enabled } }
    public func pretty(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesPretty = enabled } }
    public func quiet(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isQuiet = enabled } }
    public func trim(_ enabled: Bool = true) -> Self { modified(self) { $0.state.trimsWhitespace = enabled } }
    public func vimgrep(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesVimgrep = enabled } }
    public func withFilename(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.showsFilename = enabled
            if enabled { $0.state.suppressesFilename = false }
        }
    }
    public func noFilename(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled { $0.state.showsFilename = false }
            $0.state.suppressesFilename = enabled
        }
    }
    public func sort(_ key: RgSortKey) -> Self {
        modified(self) {
            $0.state.sortKey = key
            $0.state.sortReverseKey = nil
        }
    }
    public func sortReverse(_ key: RgSortKey) -> Self {
        modified(self) {
            $0.state.sortKey = nil
            $0.state.sortReverseKey = key
        }
    }
    public func count(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsCount = enabled } }
    public func countMatches(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsCountMatches = enabled } }
    public func filesWithMatches(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.showsFilesWithMatches = enabled }
    }
    public func filesWithoutMatch(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.showsFilesWithoutMatch = enabled }
    }
    public func json(_ enabled: Bool = true) -> Self { modified(self) { $0.state.outputsJson = enabled } }
    public func nullTerminated(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesNullTerminator = enabled }
    }
    public func byteOffset(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsByteOffset = enabled } }
    public func blockBuffered(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.usesBlockBuffering = enabled
            if enabled { $0.state.usesLineBuffering = false }
        }
    }
    public func lineBuffered(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled { $0.state.usesBlockBuffering = false }
            $0.state.usesLineBuffering = enabled
        }
    }
    public func pathSeparator(_ separator: String) -> Self {
        modified(self) { $0.state.pathSeparatorOverride = separator }
    }
    public func hyperlinkFormat(_ format: String) -> Self {
        modified(self) { $0.state.hyperlinkFormatOverride = format }
    }
    public func hostnameBin(_ command: String) -> Self { modified(self) { $0.state.hostnameBinOverride = command } }
    public func includeZero(_ enabled: Bool = true) -> Self { modified(self) { $0.state.includesZero = enabled } }
    public func stats(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsStats = enabled } }
    public func debug(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isDebug = enabled } }
    public func trace(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isTrace = enabled } }

    public func listFiles(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled {
                $0.state.positionalPattern = nil
                $0.state.regexpPatterns = []
                $0.state.patternFiles = []
            }
            $0.state.listsFiles = enabled
            if enabled { $0.state.listsTypes = false }
        }
    }

    public func typeList(_ enabled: Bool = true) -> Self {
        modified(self) {
            if enabled {
                $0.state.positionalPattern = nil
                $0.state.regexpPatterns = []
                $0.state.patternFiles = []
                $0.state.listsFiles = false
            }
            $0.state.listsTypes = enabled
            if enabled { $0.state.paths = [] }
        }
    }

    public func noConfig(_ enabled: Bool = true) -> Self { modified(self) { $0.state.disablesConfig = enabled } }
    public func path(_ value: String) -> Self { modified(self) { $0.state.paths += [value] } }
    public func paths(_ values: [String]) -> Self { modified(self) { $0.state.paths += values } }

    public func command() -> Command {
        var arguments: [String] = []

        for pattern in state.regexpPatterns { arguments.append(contentsOf: ["-e", pattern]) }
        for file in state.patternFiles { arguments.append(contentsOf: ["-f", file]) }
        if let pre = state.preCommand { arguments.append(contentsOf: ["--pre", pre]) }
        for glob in state.preGlobs { arguments.append(contentsOf: ["--pre-glob", glob]) }
        if state.searchesZip { arguments.append("-z") }

        if state.isCaseSensitive { arguments.append("-s") }
        if state.isCaseInsensitive { arguments.append("-i") }
        if state.isSmartCase { arguments.append("-S") }
        if state.usesFixedStrings { arguments.append("-F") }
        if state.isInverted { arguments.append("-v") }
        if state.isWordRegexp { arguments.append("-w") }
        if state.isLineRegexp { arguments.append("-x") }
        if let count = state.maxCount { arguments.append(contentsOf: ["-m", String(count)]) }
        if state.isMultiline { arguments.append("-U") }
        if state.isMultilineDotAll { arguments.append("--multiline-dotall") }
        if state.usesPcre2 { arguments.append("-P") }
        if let engine = state.engineOverride { arguments.append(contentsOf: ["--engine", engine.rawValue]) }
        if let encoding = state.encodingOverride { arguments.append(contentsOf: ["-E", encoding]) }
        if state.usesCrlf { arguments.append("--crlf") }
        if state.usesNullData { arguments.append("--null-data") }
        if state.disablesUnicode { arguments.append("--no-unicode") }
        if state.treatsAsText { arguments.append("-a") }
        if state.stopsOnNonmatch { arguments.append("--stop-on-nonmatch") }
        if state.usesMmap { arguments.append("--mmap") }
        if state.disablesMmap { arguments.append("--no-mmap") }
        if let threads = state.threadCount { arguments.append(contentsOf: ["-j", String(threads)]) }
        if let limit = state.dfaSizeLimitOverride { arguments.append(contentsOf: ["--dfa-size-limit", limit]) }
        if let limit = state.regexSizeLimitOverride { arguments.append(contentsOf: ["--regex-size-limit", limit]) }
        if state.usesAutoHybridRegex { arguments.append("--auto-hybrid-regex") }
        if state.disablesPcre2Unicode { arguments.append("--no-pcre2-unicode") }

        for glob in state.globs { arguments.append(contentsOf: ["-g", glob]) }
        for iglob in state.iglobs { arguments.append(contentsOf: ["--iglob", iglob]) }
        if state.isGlobCaseInsensitive { arguments.append("--glob-case-insensitive") }
        for typeAdd in state.typeAdds { arguments.append(contentsOf: ["--type-add", typeAdd]) }
        for typeClear in state.typeClears { arguments.append(contentsOf: ["--type-clear", typeClear]) }
        for fileType in state.types { arguments.append(contentsOf: ["-t", fileType]) }
        for fileType in state.typesNot { arguments.append(contentsOf: ["-T", fileType]) }
        if state.showsHidden { arguments.append("--hidden") }
        if state.followsSymlinks { arguments.append("-L") }
        if let depth = state.maxDepthOverride { arguments.append(contentsOf: ["-d", String(depth)]) }
        if let size = state.maxFilesizeOverride { arguments.append(contentsOf: ["--max-filesize", size]) }
        if state.disablesIgnore { arguments.append("--no-ignore") }
        if state.disablesIgnoreDot { arguments.append("--no-ignore-dot") }
        if state.disablesIgnoreExclude { arguments.append("--no-ignore-exclude") }
        if state.disablesIgnoreParent { arguments.append("--no-ignore-parent") }
        if state.disablesIgnoreGlobal { arguments.append("--no-ignore-global") }
        if state.disablesIgnoreVcs { arguments.append("--no-ignore-vcs") }
        if state.disablesIgnoreFiles { arguments.append("--no-ignore-files") }
        for file in state.ignoreFiles { arguments.append(contentsOf: ["--ignore-file", file]) }
        if state.isIgnoreFileCaseInsensitive { arguments.append("--ignore-file-case-insensitive") }
        if state.disablesRequireGit { arguments.append("--no-require-git") }
        if state.usesOneFileSystem { arguments.append("--one-file-system") }
        for _ in 0..<state.unrestrictedLevel { arguments.append("-u") }
        if state.searchesBinary { arguments.append("--binary") }

        if let lines = state.afterContextLines { arguments.append(contentsOf: ["-A", String(lines)]) }
        if let lines = state.beforeContextLines { arguments.append(contentsOf: ["-B", String(lines)]) }
        if let lines = state.contextLines { arguments.append(contentsOf: ["-C", String(lines)]) }
        if let sep = state.contextSeparatorOverride { arguments.append(contentsOf: ["--context-separator", sep]) }
        if let sep = state.fieldContextSeparatorOverride {
            arguments.append(contentsOf: ["--field-context-separator", sep])
        }
        if let sep = state.fieldMatchSeparatorOverride {
            arguments.append(contentsOf: ["--field-match-separator", sep])
        }
        if let when = state.colorWhen { arguments.append(contentsOf: ["--color", when.rawValue]) }
        for spec in state.colorSpecs { arguments.append(contentsOf: ["--colors", spec]) }
        if state.showsColumn { arguments.append("--column") }
        if state.usesHeading { arguments.append("--heading") }
        if state.showsLineNumber { arguments.append("-n") }
        if state.suppressesLineNumber { arguments.append("-N") }
        if let cols = state.maxColumnsOverride { arguments.append(contentsOf: ["-M", String(cols)]) }
        if state.showsMaxColumnsPreview { arguments.append("--max-columns-preview") }
        if state.showsOnlyMatching { arguments.append("-o") }
        if let replacement = state.replacementText { arguments.append(contentsOf: ["-r", replacement]) }
        if state.usesPassthru { arguments.append("--passthru") }
        if state.usesPretty { arguments.append("-p") }
        if state.isQuiet { arguments.append("-q") }
        if state.trimsWhitespace { arguments.append("--trim") }
        if state.usesVimgrep { arguments.append("--vimgrep") }
        if state.showsFilename { arguments.append("-H") }
        if state.suppressesFilename { arguments.append("-I") }
        if let key = state.sortKey { arguments.append(contentsOf: ["--sort", key.rawValue]) }
        if let key = state.sortReverseKey { arguments.append(contentsOf: ["--sortr", key.rawValue]) }
        if state.showsCount { arguments.append("-c") }
        if state.showsCountMatches { arguments.append("--count-matches") }
        if state.showsFilesWithMatches { arguments.append("-l") }
        if state.showsFilesWithoutMatch { arguments.append("--files-without-match") }
        if state.outputsJson { arguments.append("--json") }
        if state.usesNullTerminator { arguments.append("-0") }
        if state.showsByteOffset { arguments.append("-b") }
        if state.usesBlockBuffering { arguments.append("--block-buffered") }
        if state.usesLineBuffering { arguments.append("--line-buffered") }
        if let sep = state.pathSeparatorOverride { arguments.append(contentsOf: ["--path-separator", sep]) }
        if let format = state.hyperlinkFormatOverride { arguments.append(contentsOf: ["--hyperlink-format", format]) }
        if let bin = state.hostnameBinOverride { arguments.append(contentsOf: ["--hostname-bin", bin]) }
        if state.includesZero { arguments.append("--include-zero") }
        if state.showsStats { arguments.append("--stats") }
        if state.isDebug { arguments.append("--debug") }
        if state.isTrace { arguments.append("--trace") }

        if state.listsFiles { arguments.append("--files") }
        if state.listsTypes { arguments.append("--type-list") }
        if state.disablesConfig { arguments.append("--no-config") }

        if !state.listsFiles, !state.listsTypes, let pattern = state.positionalPattern {
            arguments.append("--")
            arguments.append(pattern)
        }

        if !state.listsTypes {
            arguments.append(contentsOf: state.paths)
        }

        let base = Command("rg")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var positionalPattern: String? = nil
    var regexpPatterns: [String] = []
    var patternFiles: [String] = []
    var preCommand: String? = nil
    var preGlobs: [String] = []
    var searchesZip: Bool = false
    var isCaseSensitive: Bool = false
    var isCaseInsensitive: Bool = false
    var isSmartCase: Bool = false
    var usesFixedStrings: Bool = false
    var isInverted: Bool = false
    var isWordRegexp: Bool = false
    var isLineRegexp: Bool = false
    var maxCount: Int? = nil
    var isMultiline: Bool = false
    var isMultilineDotAll: Bool = false
    var usesPcre2: Bool = false
    var engineOverride: RgEngine? = nil
    var encodingOverride: String? = nil
    var usesCrlf: Bool = false
    var usesNullData: Bool = false
    var disablesUnicode: Bool = false
    var treatsAsText: Bool = false
    var stopsOnNonmatch: Bool = false
    var usesMmap: Bool = false
    var disablesMmap: Bool = false
    var threadCount: Int? = nil
    var dfaSizeLimitOverride: String? = nil
    var regexSizeLimitOverride: String? = nil
    var usesAutoHybridRegex: Bool = false
    var disablesPcre2Unicode: Bool = false
    var globs: [String] = []
    var iglobs: [String] = []
    var isGlobCaseInsensitive: Bool = false
    var types: [String] = []
    var typesNot: [String] = []
    var typeAdds: [String] = []
    var typeClears: [String] = []
    var showsHidden: Bool = false
    var followsSymlinks: Bool = false
    var maxDepthOverride: Int? = nil
    var maxFilesizeOverride: String? = nil
    var disablesIgnore: Bool = false
    var disablesIgnoreDot: Bool = false
    var disablesIgnoreExclude: Bool = false
    var disablesIgnoreParent: Bool = false
    var disablesIgnoreGlobal: Bool = false
    var disablesIgnoreVcs: Bool = false
    var disablesIgnoreFiles: Bool = false
    var ignoreFiles: [String] = []
    var isIgnoreFileCaseInsensitive: Bool = false
    var disablesRequireGit: Bool = false
    var usesOneFileSystem: Bool = false
    var unrestrictedLevel: Int = 0
    var searchesBinary: Bool = false
    var afterContextLines: Int? = nil
    var beforeContextLines: Int? = nil
    var contextLines: Int? = nil
    var contextSeparatorOverride: String? = nil
    var fieldContextSeparatorOverride: String? = nil
    var fieldMatchSeparatorOverride: String? = nil
    var colorWhen: RgColorWhen? = nil
    var colorSpecs: [String] = []
    var showsColumn: Bool = false
    var usesHeading: Bool = false
    var showsLineNumber: Bool = false
    var suppressesLineNumber: Bool = false
    var maxColumnsOverride: Int? = nil
    var showsMaxColumnsPreview: Bool = false
    var showsOnlyMatching: Bool = false
    var replacementText: String? = nil
    var usesPassthru: Bool = false
    var usesPretty: Bool = false
    var isQuiet: Bool = false
    var trimsWhitespace: Bool = false
    var usesVimgrep: Bool = false
    var showsFilename: Bool = false
    var suppressesFilename: Bool = false
    var sortKey: RgSortKey? = nil
    var sortReverseKey: RgSortKey? = nil
    var showsCount: Bool = false
    var showsCountMatches: Bool = false
    var showsFilesWithMatches: Bool = false
    var showsFilesWithoutMatch: Bool = false
    var outputsJson: Bool = false
    var usesNullTerminator: Bool = false
    var showsByteOffset: Bool = false
    var usesBlockBuffering: Bool = false
    var usesLineBuffering: Bool = false
    var pathSeparatorOverride: String? = nil
    var hyperlinkFormatOverride: String? = nil
    var hostnameBinOverride: String? = nil
    var includesZero: Bool = false
    var showsStats: Bool = false
    var isDebug: Bool = false
    var isTrace: Bool = false
    var listsFiles: Bool = false
    var listsTypes: Bool = false
    var disablesConfig: Bool = false
    var paths: [String] = []
}
#endif
