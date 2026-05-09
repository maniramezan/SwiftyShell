# ``Rg``

A fluent wrapper for searching text with `rg` (ripgrep).

Use ``Rg`` for fast recursive regex searches with automatic gitignore
filtering, file type selection, context lines, JSON output, and more.
Each run returns ``ShellOutput`` with matching lines in `stdout`.

Search Swift files for TODO comments with line numbers:

```swift
let result = try await Rg("TODO|FIXME", context: context)
    .type("swift")
    .lineNumber()
    .path("Sources")
    .run()
```

Use ``fixedStrings(_:)`` for literal matching:

```swift
let result = try await Rg("hello.world", context: context)
    .fixedStrings()
    .ignoreCase()
    .path(".")
    .run()
```

Use ``pcre2(_:)`` for look-around and backreference support:

```swift
let result = try await Rg("(?<=func )\\w+", context: context)
    .pcre2()
    .type("swift")
    .path("Sources")
    .run()
```

When composing pipelines, build a ``Command`` from the typed family:

```swift
let output = try await Command("cat", arguments: "access.log")
    .pipe(to: Rg("ERROR").command())
    .run(in: context)
```

## Topics

### Creating a Search

- ``init(_:context:)``
- ``init(context:)``

### Input Options

- ``regexp(_:)``
- ``patternFile(_:)``
- ``pre(_:)``
- ``preGlob(_:)``
- ``searchZip(_:)``

### Search Options

- ``caseSensitive(_:)``
- ``ignoreCase(_:)``
- ``smartCase(_:)``
- ``fixedStrings(_:)``
- ``invertMatch(_:)``
- ``wordRegexp(_:)``
- ``lineRegexp(_:)``
- ``maxCount(_:)``
- ``multiline(_:)``
- ``multilineDotAll(_:)``
- ``pcre2(_:)``
- ``engine(_:)``
- ``encoding(_:)``
- ``crlf(_:)``
- ``nullData(_:)``
- ``noUnicode(_:)``
- ``text(_:)``
- ``stopOnNonmatch(_:)``
- ``mmap(_:)``
- ``noMmap(_:)``
- ``threads(_:)``
- ``dfaSizeLimit(_:)``
- ``regexSizeLimit(_:)``
- ``autoHybridRegex(_:)``
- ``noPcre2Unicode(_:)``

### Filter Options

- ``glob(_:)``
- ``iglob(_:)``
- ``globCaseInsensitive(_:)``
- ``type(_:)``
- ``typeNot(_:)``
- ``typeAdd(_:)``
- ``typeClear(_:)``
- ``hidden(_:)``
- ``follow(_:)``
- ``maxDepth(_:)``
- ``maxFilesize(_:)``
- ``noIgnore(_:)``
- ``noIgnoreDot(_:)``
- ``noIgnoreExclude(_:)``
- ``noIgnoreParent(_:)``
- ``noIgnoreGlobal(_:)``
- ``noIgnoreVcs(_:)``
- ``noIgnoreFiles(_:)``
- ``ignoreFile(_:)``
- ``ignoreFileCaseInsensitive(_:)``
- ``noRequireGit(_:)``
- ``oneFileSystem(_:)``
- ``unrestricted()``
- ``binary(_:)``

### Output Options

- ``afterContext(_:)``
- ``beforeContext(_:)``
- ``context(_:)``
- ``contextSeparator(_:)``
- ``fieldContextSeparator(_:)``
- ``fieldMatchSeparator(_:)``
- ``color(_:)``
- ``colors(_:)``
- ``column(_:)``
- ``heading(_:)``
- ``lineNumber(_:)``
- ``noLineNumber(_:)``
- ``maxColumns(_:)``
- ``maxColumnsPreview(_:)``
- ``onlyMatching(_:)``
- ``replace(_:)``
- ``passthru(_:)``
- ``pretty(_:)``
- ``quiet(_:)``
- ``trim(_:)``
- ``vimgrep(_:)``
- ``withFilename(_:)``
- ``noFilename(_:)``
- ``sort(_:)``
- ``sortReverse(_:)``
- ``count(_:)``
- ``countMatches(_:)``
- ``filesWithMatches(_:)``
- ``filesWithoutMatch(_:)``
- ``json(_:)``
- ``nullTerminated(_:)``
- ``byteOffset(_:)``
- ``blockBuffered(_:)``
- ``lineBuffered(_:)``
- ``pathSeparator(_:)``
- ``hyperlinkFormat(_:)``
- ``hostnameBin(_:)``
- ``includeZero(_:)``
- ``stats(_:)``
- ``debug(_:)``
- ``trace(_:)``

### Special Modes

- ``listFiles(_:)``
- ``typeList(_:)``
- ``noConfig(_:)``

### Search Paths

- ``path(_:)``
- ``paths(_:)``

### Running

- ``command()``

### Related Types

- ``RgEngine``
- ``RgSortKey``
- ``RgColorWhen``
