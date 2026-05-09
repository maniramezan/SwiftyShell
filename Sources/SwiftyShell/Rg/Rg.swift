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
    private let state: State

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
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `rg` command's stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `rg` command's stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    public func regexp(_ pattern: String) -> Self {
        copy(
            positionalPattern: .some(nil),
            regexpPatterns: state.regexpPatterns + [pattern],
            listsFiles: false,
            listsTypes: false
        )
    }

    public func patternFile(_ path: String) -> Self {
        copy(
            positionalPattern: .some(nil),
            patternFiles: state.patternFiles + [path],
            listsFiles: false,
            listsTypes: false
        )
    }

    public func pre(_ command: String) -> Self { copy(preCommand: command) }
    public func preGlob(_ glob: String) -> Self { copy(preGlobs: state.preGlobs + [glob]) }
    public func searchZip(_ enabled: Bool = true) -> Self { copy(searchesZip: enabled) }

    public func caseSensitive(_ enabled: Bool = true) -> Self {
        copy(
            isCaseSensitive: enabled,
            isCaseInsensitive: enabled ? false : nil,
            isSmartCase: enabled ? false : nil
        )
    }

    public func ignoreCase(_ enabled: Bool = true) -> Self {
        copy(
            isCaseSensitive: enabled ? false : nil,
            isCaseInsensitive: enabled,
            isSmartCase: enabled ? false : nil
        )
    }

    public func smartCase(_ enabled: Bool = true) -> Self {
        copy(
            isCaseSensitive: enabled ? false : nil,
            isCaseInsensitive: enabled ? false : nil,
            isSmartCase: enabled
        )
    }

    public func fixedStrings(_ enabled: Bool = true) -> Self { copy(usesFixedStrings: enabled) }
    public func invertMatch(_ enabled: Bool = true) -> Self { copy(isInverted: enabled) }
    public func wordRegexp(_ enabled: Bool = true) -> Self { copy(isWordRegexp: enabled) }
    public func lineRegexp(_ enabled: Bool = true) -> Self { copy(isLineRegexp: enabled) }
    public func maxCount(_ count: Int) -> Self { copy(maxCount: count) }
    public func multiline(_ enabled: Bool = true) -> Self { copy(isMultiline: enabled) }
    public func multilineDotAll(_ enabled: Bool = true) -> Self { copy(isMultilineDotAll: enabled) }

    public func pcre2(_ enabled: Bool = true) -> Self {
        copy(usesPcre2: enabled, engineOverride: enabled ? .some(nil) : nil)
    }

    public func engine(_ engine: RgEngine) -> Self {
        copy(usesPcre2: false, engineOverride: .some(engine))
    }

    public func encoding(_ encoding: String) -> Self { copy(encodingOverride: encoding) }
    public func crlf(_ enabled: Bool = true) -> Self { copy(usesCrlf: enabled) }
    public func nullData(_ enabled: Bool = true) -> Self { copy(usesNullData: enabled) }
    public func noUnicode(_ enabled: Bool = true) -> Self { copy(disablesUnicode: enabled) }
    public func text(_ enabled: Bool = true) -> Self { copy(treatsAsText: enabled) }
    public func stopOnNonmatch(_ enabled: Bool = true) -> Self { copy(stopsOnNonmatch: enabled) }
    public func mmap(_ enabled: Bool = true) -> Self { copy(usesMmap: enabled) }
    public func noMmap(_ enabled: Bool = true) -> Self { copy(disablesMmap: enabled) }
    public func threads(_ count: Int) -> Self { copy(threadCount: count) }
    public func dfaSizeLimit(_ limit: String) -> Self { copy(dfaSizeLimitOverride: limit) }
    public func regexSizeLimit(_ limit: String) -> Self { copy(regexSizeLimitOverride: limit) }
    public func autoHybridRegex(_ enabled: Bool = true) -> Self { copy(usesAutoHybridRegex: enabled) }
    public func noPcre2Unicode(_ enabled: Bool = true) -> Self { copy(disablesPcre2Unicode: enabled) }

    public func glob(_ pattern: String) -> Self { copy(globs: state.globs + [pattern]) }
    public func iglob(_ pattern: String) -> Self { copy(iglobs: state.iglobs + [pattern]) }
    public func globCaseInsensitive(_ enabled: Bool = true) -> Self { copy(isGlobCaseInsensitive: enabled) }
    public func type(_ fileType: String) -> Self { copy(types: state.types + [fileType]) }
    public func typeNot(_ fileType: String) -> Self { copy(typesNot: state.typesNot + [fileType]) }
    public func typeAdd(_ spec: String) -> Self { copy(typeAdds: state.typeAdds + [spec]) }
    public func typeClear(_ fileType: String) -> Self { copy(typeClears: state.typeClears + [fileType]) }
    public func hidden(_ enabled: Bool = true) -> Self { copy(showsHidden: enabled) }
    public func follow(_ enabled: Bool = true) -> Self { copy(followsSymlinks: enabled) }
    public func maxDepth(_ depth: Int) -> Self { copy(maxDepthOverride: depth) }
    public func maxFilesize(_ size: String) -> Self { copy(maxFilesizeOverride: size) }
    public func noIgnore(_ enabled: Bool = true) -> Self { copy(disablesIgnore: enabled) }
    public func noIgnoreDot(_ enabled: Bool = true) -> Self { copy(disablesIgnoreDot: enabled) }
    public func noIgnoreExclude(_ enabled: Bool = true) -> Self { copy(disablesIgnoreExclude: enabled) }
    public func noIgnoreParent(_ enabled: Bool = true) -> Self { copy(disablesIgnoreParent: enabled) }
    public func noIgnoreGlobal(_ enabled: Bool = true) -> Self { copy(disablesIgnoreGlobal: enabled) }
    public func noIgnoreVcs(_ enabled: Bool = true) -> Self { copy(disablesIgnoreVcs: enabled) }
    public func noIgnoreFiles(_ enabled: Bool = true) -> Self { copy(disablesIgnoreFiles: enabled) }
    public func ignoreFile(_ path: String) -> Self { copy(ignoreFiles: state.ignoreFiles + [path]) }
    public func ignoreFileCaseInsensitive(_ enabled: Bool = true) -> Self { copy(isIgnoreFileCaseInsensitive: enabled) }
    public func noRequireGit(_ enabled: Bool = true) -> Self { copy(disablesRequireGit: enabled) }
    public func oneFileSystem(_ enabled: Bool = true) -> Self { copy(usesOneFileSystem: enabled) }
    public func unrestricted() -> Self { copy(unrestrictedLevel: state.unrestrictedLevel + 1) }
    public func binary(_ enabled: Bool = true) -> Self { copy(searchesBinary: enabled) }

    public func afterContext(_ lines: Int) -> Self { copy(afterContextLines: lines) }
    public func beforeContext(_ lines: Int) -> Self { copy(beforeContextLines: lines) }
    public func context(_ lines: Int) -> Self { copy(contextLines: lines) }
    public func contextSeparator(_ separator: String) -> Self { copy(contextSeparatorOverride: separator) }
    public func fieldContextSeparator(_ separator: String) -> Self { copy(fieldContextSeparatorOverride: separator) }
    public func fieldMatchSeparator(_ separator: String) -> Self { copy(fieldMatchSeparatorOverride: separator) }
    public func color(_ when: RgColorWhen) -> Self { copy(colorWhen: when) }
    public func colors(_ spec: String) -> Self { copy(colorSpecs: state.colorSpecs + [spec]) }
    public func column(_ enabled: Bool = true) -> Self { copy(showsColumn: enabled) }
    public func heading(_ enabled: Bool = true) -> Self { copy(usesHeading: enabled) }
    public func lineNumber(_ enabled: Bool = true) -> Self {
        copy(showsLineNumber: enabled, suppressesLineNumber: enabled ? false : nil)
    }
    public func noLineNumber(_ enabled: Bool = true) -> Self {
        copy(showsLineNumber: enabled ? false : nil, suppressesLineNumber: enabled)
    }
    public func maxColumns(_ count: Int) -> Self { copy(maxColumnsOverride: count) }
    public func maxColumnsPreview(_ enabled: Bool = true) -> Self { copy(showsMaxColumnsPreview: enabled) }
    public func onlyMatching(_ enabled: Bool = true) -> Self { copy(showsOnlyMatching: enabled) }
    public func replace(_ text: String) -> Self { copy(replacementText: text) }
    public func passthru(_ enabled: Bool = true) -> Self { copy(usesPassthru: enabled) }
    public func pretty(_ enabled: Bool = true) -> Self { copy(usesPretty: enabled) }
    public func quiet(_ enabled: Bool = true) -> Self { copy(isQuiet: enabled) }
    public func trim(_ enabled: Bool = true) -> Self { copy(trimsWhitespace: enabled) }
    public func vimgrep(_ enabled: Bool = true) -> Self { copy(usesVimgrep: enabled) }
    public func withFilename(_ enabled: Bool = true) -> Self {
        copy(showsFilename: enabled, suppressesFilename: enabled ? false : nil)
    }
    public func noFilename(_ enabled: Bool = true) -> Self {
        copy(showsFilename: enabled ? false : nil, suppressesFilename: enabled)
    }
    public func sort(_ key: RgSortKey) -> Self {
        copy(sortKey: .some(key), sortReverseKey: .some(nil))
    }
    public func sortReverse(_ key: RgSortKey) -> Self {
        copy(sortKey: .some(nil), sortReverseKey: .some(key))
    }
    public func count(_ enabled: Bool = true) -> Self { copy(showsCount: enabled) }
    public func countMatches(_ enabled: Bool = true) -> Self { copy(showsCountMatches: enabled) }
    public func filesWithMatches(_ enabled: Bool = true) -> Self { copy(showsFilesWithMatches: enabled) }
    public func filesWithoutMatch(_ enabled: Bool = true) -> Self { copy(showsFilesWithoutMatch: enabled) }
    public func json(_ enabled: Bool = true) -> Self { copy(outputsJson: enabled) }
    public func nullTerminated(_ enabled: Bool = true) -> Self { copy(usesNullTerminator: enabled) }
    public func byteOffset(_ enabled: Bool = true) -> Self { copy(showsByteOffset: enabled) }
    public func blockBuffered(_ enabled: Bool = true) -> Self { copy(usesBlockBuffering: enabled) }
    public func lineBuffered(_ enabled: Bool = true) -> Self { copy(usesLineBuffering: enabled) }
    public func pathSeparator(_ separator: String) -> Self { copy(pathSeparatorOverride: separator) }
    public func hyperlinkFormat(_ format: String) -> Self { copy(hyperlinkFormatOverride: format) }
    public func hostnameBin(_ command: String) -> Self { copy(hostnameBinOverride: command) }
    public func includeZero(_ enabled: Bool = true) -> Self { copy(includesZero: enabled) }
    public func stats(_ enabled: Bool = true) -> Self { copy(showsStats: enabled) }
    public func debug(_ enabled: Bool = true) -> Self { copy(isDebug: enabled) }
    public func trace(_ enabled: Bool = true) -> Self { copy(isTrace: enabled) }

    public func listFiles(_ enabled: Bool = true) -> Self {
        copy(
            positionalPattern: enabled ? .some(nil) : nil,
            regexpPatterns: enabled ? [] : nil,
            patternFiles: enabled ? [] : nil,
            listsFiles: enabled,
            listsTypes: enabled ? false : nil
        )
    }

    public func typeList(_ enabled: Bool = true) -> Self {
        copy(
            positionalPattern: enabled ? .some(nil) : nil,
            regexpPatterns: enabled ? [] : nil,
            patternFiles: enabled ? [] : nil,
            listsFiles: enabled ? false : nil,
            listsTypes: enabled,
            paths: enabled ? [] : nil
        )
    }

    public func noConfig(_ enabled: Bool = true) -> Self { copy(disablesConfig: enabled) }
    public func path(_ value: String) -> Self { copy(paths: state.paths + [value]) }
    public func paths(_ values: [String]) -> Self { copy(paths: state.paths + values) }

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

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        positionalPattern: String?? = nil,
        regexpPatterns: [String]? = nil,
        patternFiles: [String]? = nil,
        preCommand: String?? = nil,
        preGlobs: [String]? = nil,
        searchesZip: Bool? = nil,
        isCaseSensitive: Bool? = nil,
        isCaseInsensitive: Bool? = nil,
        isSmartCase: Bool? = nil,
        usesFixedStrings: Bool? = nil,
        isInverted: Bool? = nil,
        isWordRegexp: Bool? = nil,
        isLineRegexp: Bool? = nil,
        maxCount: Int?? = nil,
        isMultiline: Bool? = nil,
        isMultilineDotAll: Bool? = nil,
        usesPcre2: Bool? = nil,
        engineOverride: RgEngine?? = nil,
        encodingOverride: String?? = nil,
        usesCrlf: Bool? = nil,
        usesNullData: Bool? = nil,
        disablesUnicode: Bool? = nil,
        treatsAsText: Bool? = nil,
        stopsOnNonmatch: Bool? = nil,
        usesMmap: Bool? = nil,
        disablesMmap: Bool? = nil,
        threadCount: Int?? = nil,
        dfaSizeLimitOverride: String?? = nil,
        regexSizeLimitOverride: String?? = nil,
        usesAutoHybridRegex: Bool? = nil,
        disablesPcre2Unicode: Bool? = nil,
        globs: [String]? = nil,
        iglobs: [String]? = nil,
        isGlobCaseInsensitive: Bool? = nil,
        types: [String]? = nil,
        typesNot: [String]? = nil,
        typeAdds: [String]? = nil,
        typeClears: [String]? = nil,
        showsHidden: Bool? = nil,
        followsSymlinks: Bool? = nil,
        maxDepthOverride: Int?? = nil,
        maxFilesizeOverride: String?? = nil,
        disablesIgnore: Bool? = nil,
        disablesIgnoreDot: Bool? = nil,
        disablesIgnoreExclude: Bool? = nil,
        disablesIgnoreParent: Bool? = nil,
        disablesIgnoreGlobal: Bool? = nil,
        disablesIgnoreVcs: Bool? = nil,
        disablesIgnoreFiles: Bool? = nil,
        ignoreFiles: [String]? = nil,
        isIgnoreFileCaseInsensitive: Bool? = nil,
        disablesRequireGit: Bool? = nil,
        usesOneFileSystem: Bool? = nil,
        unrestrictedLevel: Int? = nil,
        searchesBinary: Bool? = nil,
        afterContextLines: Int?? = nil,
        beforeContextLines: Int?? = nil,
        contextLines: Int?? = nil,
        contextSeparatorOverride: String?? = nil,
        fieldContextSeparatorOverride: String?? = nil,
        fieldMatchSeparatorOverride: String?? = nil,
        colorWhen: RgColorWhen?? = nil,
        colorSpecs: [String]? = nil,
        showsColumn: Bool? = nil,
        usesHeading: Bool? = nil,
        showsLineNumber: Bool? = nil,
        suppressesLineNumber: Bool? = nil,
        maxColumnsOverride: Int?? = nil,
        showsMaxColumnsPreview: Bool? = nil,
        showsOnlyMatching: Bool? = nil,
        replacementText: String?? = nil,
        usesPassthru: Bool? = nil,
        usesPretty: Bool? = nil,
        isQuiet: Bool? = nil,
        trimsWhitespace: Bool? = nil,
        usesVimgrep: Bool? = nil,
        showsFilename: Bool? = nil,
        suppressesFilename: Bool? = nil,
        sortKey: RgSortKey?? = nil,
        sortReverseKey: RgSortKey?? = nil,
        showsCount: Bool? = nil,
        showsCountMatches: Bool? = nil,
        showsFilesWithMatches: Bool? = nil,
        showsFilesWithoutMatch: Bool? = nil,
        outputsJson: Bool? = nil,
        usesNullTerminator: Bool? = nil,
        showsByteOffset: Bool? = nil,
        usesBlockBuffering: Bool? = nil,
        usesLineBuffering: Bool? = nil,
        pathSeparatorOverride: String?? = nil,
        hyperlinkFormatOverride: String?? = nil,
        hostnameBinOverride: String?? = nil,
        includesZero: Bool? = nil,
        showsStats: Bool? = nil,
        isDebug: Bool? = nil,
        isTrace: Bool? = nil,
        listsFiles: Bool? = nil,
        listsTypes: Bool? = nil,
        disablesConfig: Bool? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                positionalPattern: positionalPattern ?? state.positionalPattern,
                regexpPatterns: regexpPatterns ?? state.regexpPatterns,
                patternFiles: patternFiles ?? state.patternFiles,
                preCommand: preCommand ?? state.preCommand,
                preGlobs: preGlobs ?? state.preGlobs,
                searchesZip: searchesZip ?? state.searchesZip,
                isCaseSensitive: isCaseSensitive ?? state.isCaseSensitive,
                isCaseInsensitive: isCaseInsensitive ?? state.isCaseInsensitive,
                isSmartCase: isSmartCase ?? state.isSmartCase,
                usesFixedStrings: usesFixedStrings ?? state.usesFixedStrings,
                isInverted: isInverted ?? state.isInverted,
                isWordRegexp: isWordRegexp ?? state.isWordRegexp,
                isLineRegexp: isLineRegexp ?? state.isLineRegexp,
                maxCount: maxCount ?? state.maxCount,
                isMultiline: isMultiline ?? state.isMultiline,
                isMultilineDotAll: isMultilineDotAll ?? state.isMultilineDotAll,
                usesPcre2: usesPcre2 ?? state.usesPcre2,
                engineOverride: engineOverride ?? state.engineOverride,
                encodingOverride: encodingOverride ?? state.encodingOverride,
                usesCrlf: usesCrlf ?? state.usesCrlf,
                usesNullData: usesNullData ?? state.usesNullData,
                disablesUnicode: disablesUnicode ?? state.disablesUnicode,
                treatsAsText: treatsAsText ?? state.treatsAsText,
                stopsOnNonmatch: stopsOnNonmatch ?? state.stopsOnNonmatch,
                usesMmap: usesMmap ?? state.usesMmap,
                disablesMmap: disablesMmap ?? state.disablesMmap,
                threadCount: threadCount ?? state.threadCount,
                dfaSizeLimitOverride: dfaSizeLimitOverride ?? state.dfaSizeLimitOverride,
                regexSizeLimitOverride: regexSizeLimitOverride ?? state.regexSizeLimitOverride,
                usesAutoHybridRegex: usesAutoHybridRegex ?? state.usesAutoHybridRegex,
                disablesPcre2Unicode: disablesPcre2Unicode ?? state.disablesPcre2Unicode,
                globs: globs ?? state.globs,
                iglobs: iglobs ?? state.iglobs,
                isGlobCaseInsensitive: isGlobCaseInsensitive ?? state.isGlobCaseInsensitive,
                types: types ?? state.types,
                typesNot: typesNot ?? state.typesNot,
                typeAdds: typeAdds ?? state.typeAdds,
                typeClears: typeClears ?? state.typeClears,
                showsHidden: showsHidden ?? state.showsHidden,
                followsSymlinks: followsSymlinks ?? state.followsSymlinks,
                maxDepthOverride: maxDepthOverride ?? state.maxDepthOverride,
                maxFilesizeOverride: maxFilesizeOverride ?? state.maxFilesizeOverride,
                disablesIgnore: disablesIgnore ?? state.disablesIgnore,
                disablesIgnoreDot: disablesIgnoreDot ?? state.disablesIgnoreDot,
                disablesIgnoreExclude: disablesIgnoreExclude ?? state.disablesIgnoreExclude,
                disablesIgnoreParent: disablesIgnoreParent ?? state.disablesIgnoreParent,
                disablesIgnoreGlobal: disablesIgnoreGlobal ?? state.disablesIgnoreGlobal,
                disablesIgnoreVcs: disablesIgnoreVcs ?? state.disablesIgnoreVcs,
                disablesIgnoreFiles: disablesIgnoreFiles ?? state.disablesIgnoreFiles,
                ignoreFiles: ignoreFiles ?? state.ignoreFiles,
                isIgnoreFileCaseInsensitive: isIgnoreFileCaseInsensitive ?? state.isIgnoreFileCaseInsensitive,
                disablesRequireGit: disablesRequireGit ?? state.disablesRequireGit,
                usesOneFileSystem: usesOneFileSystem ?? state.usesOneFileSystem,
                unrestrictedLevel: unrestrictedLevel ?? state.unrestrictedLevel,
                searchesBinary: searchesBinary ?? state.searchesBinary,
                afterContextLines: afterContextLines ?? state.afterContextLines,
                beforeContextLines: beforeContextLines ?? state.beforeContextLines,
                contextLines: contextLines ?? state.contextLines,
                contextSeparatorOverride: contextSeparatorOverride ?? state.contextSeparatorOverride,
                fieldContextSeparatorOverride: fieldContextSeparatorOverride ?? state.fieldContextSeparatorOverride,
                fieldMatchSeparatorOverride: fieldMatchSeparatorOverride ?? state.fieldMatchSeparatorOverride,
                colorWhen: colorWhen ?? state.colorWhen,
                colorSpecs: colorSpecs ?? state.colorSpecs,
                showsColumn: showsColumn ?? state.showsColumn,
                usesHeading: usesHeading ?? state.usesHeading,
                showsLineNumber: showsLineNumber ?? state.showsLineNumber,
                suppressesLineNumber: suppressesLineNumber ?? state.suppressesLineNumber,
                maxColumnsOverride: maxColumnsOverride ?? state.maxColumnsOverride,
                showsMaxColumnsPreview: showsMaxColumnsPreview ?? state.showsMaxColumnsPreview,
                showsOnlyMatching: showsOnlyMatching ?? state.showsOnlyMatching,
                replacementText: replacementText ?? state.replacementText,
                usesPassthru: usesPassthru ?? state.usesPassthru,
                usesPretty: usesPretty ?? state.usesPretty,
                isQuiet: isQuiet ?? state.isQuiet,
                trimsWhitespace: trimsWhitespace ?? state.trimsWhitespace,
                usesVimgrep: usesVimgrep ?? state.usesVimgrep,
                showsFilename: showsFilename ?? state.showsFilename,
                suppressesFilename: suppressesFilename ?? state.suppressesFilename,
                sortKey: sortKey ?? state.sortKey,
                sortReverseKey: sortReverseKey ?? state.sortReverseKey,
                showsCount: showsCount ?? state.showsCount,
                showsCountMatches: showsCountMatches ?? state.showsCountMatches,
                showsFilesWithMatches: showsFilesWithMatches ?? state.showsFilesWithMatches,
                showsFilesWithoutMatch: showsFilesWithoutMatch ?? state.showsFilesWithoutMatch,
                outputsJson: outputsJson ?? state.outputsJson,
                usesNullTerminator: usesNullTerminator ?? state.usesNullTerminator,
                showsByteOffset: showsByteOffset ?? state.showsByteOffset,
                usesBlockBuffering: usesBlockBuffering ?? state.usesBlockBuffering,
                usesLineBuffering: usesLineBuffering ?? state.usesLineBuffering,
                pathSeparatorOverride: pathSeparatorOverride ?? state.pathSeparatorOverride,
                hyperlinkFormatOverride: hyperlinkFormatOverride ?? state.hyperlinkFormatOverride,
                hostnameBinOverride: hostnameBinOverride ?? state.hostnameBinOverride,
                includesZero: includesZero ?? state.includesZero,
                showsStats: showsStats ?? state.showsStats,
                isDebug: isDebug ?? state.isDebug,
                isTrace: isTrace ?? state.isTrace,
                listsFiles: listsFiles ?? state.listsFiles,
                listsTypes: listsTypes ?? state.listsTypes,
                disablesConfig: disablesConfig ?? state.disablesConfig,
                paths: paths ?? state.paths
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let positionalPattern: String?
    let regexpPatterns: [String]
    let patternFiles: [String]
    let preCommand: String?
    let preGlobs: [String]
    let searchesZip: Bool
    let isCaseSensitive: Bool
    let isCaseInsensitive: Bool
    let isSmartCase: Bool
    let usesFixedStrings: Bool
    let isInverted: Bool
    let isWordRegexp: Bool
    let isLineRegexp: Bool
    let maxCount: Int?
    let isMultiline: Bool
    let isMultilineDotAll: Bool
    let usesPcre2: Bool
    let engineOverride: RgEngine?
    let encodingOverride: String?
    let usesCrlf: Bool
    let usesNullData: Bool
    let disablesUnicode: Bool
    let treatsAsText: Bool
    let stopsOnNonmatch: Bool
    let usesMmap: Bool
    let disablesMmap: Bool
    let threadCount: Int?
    let dfaSizeLimitOverride: String?
    let regexSizeLimitOverride: String?
    let usesAutoHybridRegex: Bool
    let disablesPcre2Unicode: Bool
    let globs: [String]
    let iglobs: [String]
    let isGlobCaseInsensitive: Bool
    let types: [String]
    let typesNot: [String]
    let typeAdds: [String]
    let typeClears: [String]
    let showsHidden: Bool
    let followsSymlinks: Bool
    let maxDepthOverride: Int?
    let maxFilesizeOverride: String?
    let disablesIgnore: Bool
    let disablesIgnoreDot: Bool
    let disablesIgnoreExclude: Bool
    let disablesIgnoreParent: Bool
    let disablesIgnoreGlobal: Bool
    let disablesIgnoreVcs: Bool
    let disablesIgnoreFiles: Bool
    let ignoreFiles: [String]
    let isIgnoreFileCaseInsensitive: Bool
    let disablesRequireGit: Bool
    let usesOneFileSystem: Bool
    let unrestrictedLevel: Int
    let searchesBinary: Bool
    let afterContextLines: Int?
    let beforeContextLines: Int?
    let contextLines: Int?
    let contextSeparatorOverride: String?
    let fieldContextSeparatorOverride: String?
    let fieldMatchSeparatorOverride: String?
    let colorWhen: RgColorWhen?
    let colorSpecs: [String]
    let showsColumn: Bool
    let usesHeading: Bool
    let showsLineNumber: Bool
    let suppressesLineNumber: Bool
    let maxColumnsOverride: Int?
    let showsMaxColumnsPreview: Bool
    let showsOnlyMatching: Bool
    let replacementText: String?
    let usesPassthru: Bool
    let usesPretty: Bool
    let isQuiet: Bool
    let trimsWhitespace: Bool
    let usesVimgrep: Bool
    let showsFilename: Bool
    let suppressesFilename: Bool
    let sortKey: RgSortKey?
    let sortReverseKey: RgSortKey?
    let showsCount: Bool
    let showsCountMatches: Bool
    let showsFilesWithMatches: Bool
    let showsFilesWithoutMatch: Bool
    let outputsJson: Bool
    let usesNullTerminator: Bool
    let showsByteOffset: Bool
    let usesBlockBuffering: Bool
    let usesLineBuffering: Bool
    let pathSeparatorOverride: String?
    let hyperlinkFormatOverride: String?
    let hostnameBinOverride: String?
    let includesZero: Bool
    let showsStats: Bool
    let isDebug: Bool
    let isTrace: Bool
    let listsFiles: Bool
    let listsTypes: Bool
    let disablesConfig: Bool
    let paths: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        positionalPattern: String? = nil,
        regexpPatterns: [String] = [],
        patternFiles: [String] = [],
        preCommand: String? = nil,
        preGlobs: [String] = [],
        searchesZip: Bool = false,
        isCaseSensitive: Bool = false,
        isCaseInsensitive: Bool = false,
        isSmartCase: Bool = false,
        usesFixedStrings: Bool = false,
        isInverted: Bool = false,
        isWordRegexp: Bool = false,
        isLineRegexp: Bool = false,
        maxCount: Int? = nil,
        isMultiline: Bool = false,
        isMultilineDotAll: Bool = false,
        usesPcre2: Bool = false,
        engineOverride: RgEngine? = nil,
        encodingOverride: String? = nil,
        usesCrlf: Bool = false,
        usesNullData: Bool = false,
        disablesUnicode: Bool = false,
        treatsAsText: Bool = false,
        stopsOnNonmatch: Bool = false,
        usesMmap: Bool = false,
        disablesMmap: Bool = false,
        threadCount: Int? = nil,
        dfaSizeLimitOverride: String? = nil,
        regexSizeLimitOverride: String? = nil,
        usesAutoHybridRegex: Bool = false,
        disablesPcre2Unicode: Bool = false,
        globs: [String] = [],
        iglobs: [String] = [],
        isGlobCaseInsensitive: Bool = false,
        types: [String] = [],
        typesNot: [String] = [],
        typeAdds: [String] = [],
        typeClears: [String] = [],
        showsHidden: Bool = false,
        followsSymlinks: Bool = false,
        maxDepthOverride: Int? = nil,
        maxFilesizeOverride: String? = nil,
        disablesIgnore: Bool = false,
        disablesIgnoreDot: Bool = false,
        disablesIgnoreExclude: Bool = false,
        disablesIgnoreParent: Bool = false,
        disablesIgnoreGlobal: Bool = false,
        disablesIgnoreVcs: Bool = false,
        disablesIgnoreFiles: Bool = false,
        ignoreFiles: [String] = [],
        isIgnoreFileCaseInsensitive: Bool = false,
        disablesRequireGit: Bool = false,
        usesOneFileSystem: Bool = false,
        unrestrictedLevel: Int = 0,
        searchesBinary: Bool = false,
        afterContextLines: Int? = nil,
        beforeContextLines: Int? = nil,
        contextLines: Int? = nil,
        contextSeparatorOverride: String? = nil,
        fieldContextSeparatorOverride: String? = nil,
        fieldMatchSeparatorOverride: String? = nil,
        colorWhen: RgColorWhen? = nil,
        colorSpecs: [String] = [],
        showsColumn: Bool = false,
        usesHeading: Bool = false,
        showsLineNumber: Bool = false,
        suppressesLineNumber: Bool = false,
        maxColumnsOverride: Int? = nil,
        showsMaxColumnsPreview: Bool = false,
        showsOnlyMatching: Bool = false,
        replacementText: String? = nil,
        usesPassthru: Bool = false,
        usesPretty: Bool = false,
        isQuiet: Bool = false,
        trimsWhitespace: Bool = false,
        usesVimgrep: Bool = false,
        showsFilename: Bool = false,
        suppressesFilename: Bool = false,
        sortKey: RgSortKey? = nil,
        sortReverseKey: RgSortKey? = nil,
        showsCount: Bool = false,
        showsCountMatches: Bool = false,
        showsFilesWithMatches: Bool = false,
        showsFilesWithoutMatch: Bool = false,
        outputsJson: Bool = false,
        usesNullTerminator: Bool = false,
        showsByteOffset: Bool = false,
        usesBlockBuffering: Bool = false,
        usesLineBuffering: Bool = false,
        pathSeparatorOverride: String? = nil,
        hyperlinkFormatOverride: String? = nil,
        hostnameBinOverride: String? = nil,
        includesZero: Bool = false,
        showsStats: Bool = false,
        isDebug: Bool = false,
        isTrace: Bool = false,
        listsFiles: Bool = false,
        listsTypes: Bool = false,
        disablesConfig: Bool = false,
        paths: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.positionalPattern = positionalPattern
        self.regexpPatterns = regexpPatterns
        self.patternFiles = patternFiles
        self.preCommand = preCommand
        self.preGlobs = preGlobs
        self.searchesZip = searchesZip
        self.isCaseSensitive = isCaseSensitive
        self.isCaseInsensitive = isCaseInsensitive
        self.isSmartCase = isSmartCase
        self.usesFixedStrings = usesFixedStrings
        self.isInverted = isInverted
        self.isWordRegexp = isWordRegexp
        self.isLineRegexp = isLineRegexp
        self.maxCount = maxCount
        self.isMultiline = isMultiline
        self.isMultilineDotAll = isMultilineDotAll
        self.usesPcre2 = usesPcre2
        self.engineOverride = engineOverride
        self.encodingOverride = encodingOverride
        self.usesCrlf = usesCrlf
        self.usesNullData = usesNullData
        self.disablesUnicode = disablesUnicode
        self.treatsAsText = treatsAsText
        self.stopsOnNonmatch = stopsOnNonmatch
        self.usesMmap = usesMmap
        self.disablesMmap = disablesMmap
        self.threadCount = threadCount
        self.dfaSizeLimitOverride = dfaSizeLimitOverride
        self.regexSizeLimitOverride = regexSizeLimitOverride
        self.usesAutoHybridRegex = usesAutoHybridRegex
        self.disablesPcre2Unicode = disablesPcre2Unicode
        self.globs = globs
        self.iglobs = iglobs
        self.isGlobCaseInsensitive = isGlobCaseInsensitive
        self.types = types
        self.typesNot = typesNot
        self.typeAdds = typeAdds
        self.typeClears = typeClears
        self.showsHidden = showsHidden
        self.followsSymlinks = followsSymlinks
        self.maxDepthOverride = maxDepthOverride
        self.maxFilesizeOverride = maxFilesizeOverride
        self.disablesIgnore = disablesIgnore
        self.disablesIgnoreDot = disablesIgnoreDot
        self.disablesIgnoreExclude = disablesIgnoreExclude
        self.disablesIgnoreParent = disablesIgnoreParent
        self.disablesIgnoreGlobal = disablesIgnoreGlobal
        self.disablesIgnoreVcs = disablesIgnoreVcs
        self.disablesIgnoreFiles = disablesIgnoreFiles
        self.ignoreFiles = ignoreFiles
        self.isIgnoreFileCaseInsensitive = isIgnoreFileCaseInsensitive
        self.disablesRequireGit = disablesRequireGit
        self.usesOneFileSystem = usesOneFileSystem
        self.unrestrictedLevel = unrestrictedLevel
        self.searchesBinary = searchesBinary
        self.afterContextLines = afterContextLines
        self.beforeContextLines = beforeContextLines
        self.contextLines = contextLines
        self.contextSeparatorOverride = contextSeparatorOverride
        self.fieldContextSeparatorOverride = fieldContextSeparatorOverride
        self.fieldMatchSeparatorOverride = fieldMatchSeparatorOverride
        self.colorWhen = colorWhen
        self.colorSpecs = colorSpecs
        self.showsColumn = showsColumn
        self.usesHeading = usesHeading
        self.showsLineNumber = showsLineNumber
        self.suppressesLineNumber = suppressesLineNumber
        self.maxColumnsOverride = maxColumnsOverride
        self.showsMaxColumnsPreview = showsMaxColumnsPreview
        self.showsOnlyMatching = showsOnlyMatching
        self.replacementText = replacementText
        self.usesPassthru = usesPassthru
        self.usesPretty = usesPretty
        self.isQuiet = isQuiet
        self.trimsWhitespace = trimsWhitespace
        self.usesVimgrep = usesVimgrep
        self.showsFilename = showsFilename
        self.suppressesFilename = suppressesFilename
        self.sortKey = sortKey
        self.sortReverseKey = sortReverseKey
        self.showsCount = showsCount
        self.showsCountMatches = showsCountMatches
        self.showsFilesWithMatches = showsFilesWithMatches
        self.showsFilesWithoutMatch = showsFilesWithoutMatch
        self.outputsJson = outputsJson
        self.usesNullTerminator = usesNullTerminator
        self.showsByteOffset = showsByteOffset
        self.usesBlockBuffering = usesBlockBuffering
        self.usesLineBuffering = usesLineBuffering
        self.pathSeparatorOverride = pathSeparatorOverride
        self.hyperlinkFormatOverride = hyperlinkFormatOverride
        self.hostnameBinOverride = hostnameBinOverride
        self.includesZero = includesZero
        self.showsStats = showsStats
        self.isDebug = isDebug
        self.isTrace = isTrace
        self.listsFiles = listsFiles
        self.listsTypes = listsTypes
        self.disablesConfig = disablesConfig
        self.paths = paths
    }
}
#endif
