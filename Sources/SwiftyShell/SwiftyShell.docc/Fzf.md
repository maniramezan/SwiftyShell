# ``Fzf``

A fluent wrapper for `fzf`, the command-line fuzzy finder.

``Fzf`` models a broad, fluent subset of fzf's CLI as Swift values. Use
``filter(_:)`` for non-interactive batch filtering that works naturally with
``run()`` and pipeline composition. SwiftyShell does not connect a terminal or
interactive stdin, so interactive selection is outside this execution API.

Non-interactive filter mode works like a fuzzy `grep`:

```swift
let output = try await Command("ls")
    .pipe(to: Fzf(context: context).filter("main").command())
    .run(in: context)

print(output.stdout)  // Lines matching "main"
```

Build a configured command for inspection or for a caller-supplied execution environment:

```swift
let command = Fzf(context: context)
    .scheme(.history)
    .noSort()
    .tac()
    .exact()
    .prompt("history> ")
    .bind("ctrl-r:reload(history)")
    .command()
```

## Topics

### Creating an Fzf Command

- ``init(context:)``

### Search Options

- ``extended(_:)``
- ``exact(_:)``
- ``ignoreCase(_:)``
- ``caseSensitive(_:)``
- ``literal(_:)``
- ``scheme(_:)``
- ``algo(_:)``
- ``nth(_:)``
- ``withNth(_:)``
- ``acceptNth(_:)``
- ``noSort(_:)``
- ``delimiter(_:)``
- ``tail(_:)``
- ``disabled(_:)``
- ``tiebreak(_:)``

### Input and Output

- ``read0(_:)``
- ``print0(_:)``
- ``ansi(_:)``
- ``sync(_:)``

### Display Mode

- ``height(_:)``
- ``minHeight(_:)``
- ``popup(_:)``

### Layout

- ``layout(_:)``
- ``reverse()``
- ``margin(_:)``
- ``padding(_:)``
- ``border(_:)``
- ``borderLabel(_:)``
- ``borderLabelPos(_:)``

### List Section

- ``multi(_:)``
- ``highlightLine(_:)``
- ``cycle(_:)``
- ``wrap(_:)``
- ``wrapSign(_:)``
- ``noMultiLine(_:)``
- ``raw(_:)``
- ``track(_:)``
- ``tac(_:)``
- ``gap(_:)``
- ``keepRight(_:)``
- ``scrollOff(_:)``
- ``noHscroll(_:)``
- ``hscrollOff(_:)``
- ``jumpLabels(_:)``
- ``pointer(_:)``
- ``marker(_:)``
- ``ellipsis(_:)``
- ``tabstop(_:)``
- ``scrollbar(_:)``
- ``listBorder(_:)``
- ``listLabel(_:)``

### Input Section

- ``noInput(_:)``
- ``prompt(_:)``
- ``info(_:)``
- ``noInfo(_:)``
- ``separator(_:)``
- ``ghost(_:)``
- ``filepathWord(_:)``
- ``inputBorder(_:)``
- ``inputLabel(_:)``

### Preview

- ``preview(_:)``
- ``previewWindow(_:)``
- ``previewBorder(_:)``
- ``previewLabel(_:)``
- ``previewLabelPos(_:)``

### Header and Footer

- ``header(_:)``
- ``headerLines(_:)``
- ``headerFirst(_:)``
- ``headerBorder(_:)``
- ``footer(_:)``
- ``footerBorder(_:)``

### Scripting

- ``query(_:)``
- ``select1(_:)``
- ``exit0(_:)``
- ``filter(_:)``
- ``printQuery(_:)``
- ``expect(_:)``
- ``noClear(_:)``

### Key Bindings

- ``bind(_:)``

### Advanced

- ``withShell(_:)``
- ``listen(_:)``
- ``threads(_:)``

### Directory Traversal

- ``walker(_:)``
- ``walkerRoot(_:)``
- ``walkerSkip(_:)``

### History

- ``history(_:)``
- ``historySize(_:)``

### Style and Color

- ``style(_:)``
- ``color(_:)``
- ``noColor(_:)``
- ``noBold(_:)``
- ``black(_:)``

### Other Options

- ``noMouse(_:)``
- ``noUnicode(_:)``
- ``ambidouble(_:)``

### Running

- ``command()``

### Related Types

- ``FzfScheme``
- ``FzfAlgo``
- ``FzfLayout``
- ``FzfBorderStyle``
- ``FzfInfoStyle``
- ``FzfWrapMode``
