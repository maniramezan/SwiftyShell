#if Fzf
import Foundation

/// A fluent wrapper for `fzf`, the command-line fuzzy finder.
///
/// ``Fzf`` models a broad, fluent subset of fzf's CLI as a Swift value type. SwiftyShell does not
/// provide terminal-backed interactive stdin, so use ``filter(_:)`` for non-interactive batch
/// filtering or pass the built ``Command`` to an external execution environment that supplies a
/// terminal.
///
/// Non-interactive filtering with ``filter(_:)`` fits the ``run()`` pattern naturally:
///
/// ```swift
/// let output = try await Command("ls")
///     .pipe(to: Fzf(context: context).filter("main").command())
///     .run(in: context)
///
/// print(output.stdout)  // Lines matching "main"
/// ```
///
/// Build a ``Command`` with ``command()`` to compose fzf into pipelines or pass to
/// other SwiftyShell APIs.
public struct Fzf: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an `fzf` command family bound to a shell context.
    ///
    /// All builder state starts empty. With no options configured, fzf launches in interactive
    /// mode reading candidates from stdin or its built-in file walker.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    // MARK: - Protocol conformance

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Fzf`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `fzf` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Stdout carries the selected item(s).
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Fzf`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `fzf` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `fzf` renders its UI on stderr when the
    /// output is not a TTY.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Fzf`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    // MARK: - Search options

    /// Returns a copy that enables extended-search mode.
    ///
    /// Maps to `--extended`. This is the default in fzf.
    ///
    /// - Parameter enabled: `true` to add `--extended`; `false` to add `--no-extended`.
    ///   Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func extended(_ enabled: Bool = true) -> Self {
        copy(extended: enabled)
    }

    /// Returns a copy that enables exact matching instead of fuzzy matching.
    ///
    /// Maps to `--exact`.
    ///
    /// - Parameter enabled: `true` to add `--exact`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func exact(_ enabled: Bool = true) -> Self {
        copy(exact: enabled)
    }

    /// Returns a copy that performs case-insensitive matching.
    ///
    /// Maps to `--ignore-case`. Overrides the default smart-case behavior.
    ///
    /// - Parameter enabled: `true` to add `--ignore-case`; `false` to omit it.
    ///   Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func ignoreCase(_ enabled: Bool = true) -> Self {
        copy(ignoreCase: enabled)
    }

    /// Returns a copy that performs case-sensitive matching.
    ///
    /// Maps to `--no-ignore-case`. Overrides the default smart-case behavior.
    ///
    /// - Parameter enabled: `true` to add `--no-ignore-case`; `false` to omit it.
    ///   Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func caseSensitive(_ enabled: Bool = true) -> Self {
        copy(caseSensitive: enabled)
    }

    /// Returns a copy that disables normalization of latin script letters.
    ///
    /// Maps to `--literal`.
    ///
    /// - Parameter enabled: `true` to add `--literal`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func literal(_ enabled: Bool = true) -> Self {
        copy(literal: enabled)
    }

    /// Returns a copy that uses the given scoring scheme.
    ///
    /// Maps to `--scheme=SCHEME`. Different schemes are optimized for different input types.
    ///
    /// - Parameter scheme: The ``FzfScheme`` to use.
    /// - Returns: A new ``Fzf`` value with the scheme applied.
    public func scheme(_ scheme: FzfScheme) -> Self {
        copy(scheme: scheme)
    }

    /// Returns a copy that uses the given fuzzy matching algorithm.
    ///
    /// Maps to `--algo=TYPE`. ``FzfAlgo/v2`` is the default for optimal scoring;
    /// ``FzfAlgo/v1`` is faster but may miss the highest-scoring match.
    ///
    /// - Parameter algo: The ``FzfAlgo`` to use.
    /// - Returns: A new ``Fzf`` value with the algorithm applied.
    public func algo(_ algo: FzfAlgo) -> Self {
        copy(algo: algo)
    }

    /// Returns a copy that limits the search scope to the given field indices.
    ///
    /// Maps to `--nth=N[,..]`. See the fzf man page for field index expression syntax.
    ///
    /// - Parameter value: A comma-separated list of field index expressions.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func nth(_ value: String) -> Self {
        copy(nth: value)
    }

    /// Returns a copy that transforms the presentation of each line using field expressions.
    ///
    /// Maps to `--with-nth=N[,..]`. Useful for hiding fields from display while keeping them
    /// available for output.
    ///
    /// - Parameter value: A comma-separated list of field index expressions or a template.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func withNth(_ value: String) -> Self {
        copy(withNth: value)
    }

    /// Returns a copy that defines which fields to print on accept.
    ///
    /// Maps to `--accept-nth=N[,..]`. The last delimiter is stripped from output.
    ///
    /// - Parameter value: A comma-separated list of field index expressions or a template.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func acceptNth(_ value: String) -> Self {
        copy(acceptNth: value)
    }

    /// Returns a copy that disables sorting of results.
    ///
    /// Maps to `--no-sort`.
    ///
    /// - Parameter enabled: `true` to add `--no-sort`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noSort(_ enabled: Bool = true) -> Self {
        copy(noSort: enabled)
    }

    /// Returns a copy that uses the given field delimiter regex.
    ///
    /// Maps to `--delimiter=STR`. Used for `--nth`, `--with-nth`, and field index expressions.
    ///
    /// - Parameter value: The delimiter string or regex.
    /// - Returns: A new ``Fzf`` value with the delimiter applied.
    public func delimiter(_ value: String) -> Self {
        copy(delimiter: value)
    }

    /// Returns a copy that limits the number of items kept in memory.
    ///
    /// Maps to `--tail=NUM`. Useful when browsing an endless stream of data.
    ///
    /// - Parameter count: Maximum number of items to keep in memory.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func tail(_ count: Int) -> Self {
        copy(tail: count)
    }

    /// Returns a copy that disables search, making fzf a simple selector.
    ///
    /// Maps to `--disabled`.
    ///
    /// - Parameter enabled: `true` to add `--disabled`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func disabled(_ enabled: Bool = true) -> Self {
        copy(disabled: enabled)
    }

    /// Returns a copy that uses the given tiebreak criteria.
    ///
    /// Maps to `--tiebreak=CRI[,..]`. Criteria include `length`, `chunk`, `begin`, `end`,
    /// `index`, and `pathname`.
    ///
    /// - Parameter value: Comma-separated list of sort criteria.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func tiebreak(_ value: String) -> Self {
        copy(tiebreak: value)
    }

    // MARK: - Input/Output

    /// Returns a copy that reads input delimited by NUL characters instead of newlines.
    ///
    /// Maps to `--read0`.
    ///
    /// - Parameter enabled: `true` to add `--read0`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func read0(_ enabled: Bool = true) -> Self {
        copy(read0: enabled)
    }

    /// Returns a copy that prints output delimited by NUL characters instead of newlines.
    ///
    /// Maps to `--print0`.
    ///
    /// - Parameter enabled: `true` to add `--print0`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func print0(_ enabled: Bool = true) -> Self {
        copy(print0: enabled)
    }

    /// Returns a copy that enables processing of ANSI color codes in input.
    ///
    /// Maps to `--ansi`. Note that this makes initial scanning slower.
    ///
    /// - Parameter enabled: `true` to add `--ansi`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func ansi(_ enabled: Bool = true) -> Self {
        copy(ansi: enabled)
    }

    /// Returns a copy that enables synchronous search for multi-staged filtering.
    ///
    /// Maps to `--sync`. fzf will launch the finder only after the input stream is complete.
    ///
    /// - Parameter enabled: `true` to add `--sync`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func sync(_ enabled: Bool = true) -> Self {
        copy(sync: enabled)
    }

    // MARK: - Display mode

    /// Returns a copy that displays fzf below the cursor with the given height.
    ///
    /// Maps to `--height=HEIGHT`. Accepts absolute values, percentages (`40%`), and
    /// adaptive prefixes (`~100%`).
    ///
    /// - Parameter value: The height specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func height(_ value: String) -> Self {
        copy(height: value)
    }

    /// Returns a copy that sets the minimum height when `--height` is a percentage.
    ///
    /// Maps to `--min-height=HEIGHT`. Add `+` suffix to auto-increase.
    ///
    /// - Parameter value: The minimum height specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func minHeight(_ value: String) -> Self {
        copy(minHeight: value)
    }

    /// Returns a copy that starts fzf in a tmux popup or Zellij floating pane.
    ///
    /// Maps to `--popup=SPEC`. Requires tmux 3.3+ or Zellij 0.44+.
    /// Pass `nil` to use the default `center,50%`.
    ///
    /// - Parameter value: The popup position and size specification, or `nil` for defaults.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func popup(_ value: String? = nil) -> Self {
        copy(popup: .some(value))
    }

    // MARK: - Layout

    /// Returns a copy that uses the given layout direction.
    ///
    /// Maps to `--layout=LAYOUT`.
    ///
    /// - Parameter layout: The ``FzfLayout`` to use.
    /// - Returns: A new ``Fzf`` value with the layout applied.
    public func layout(_ layout: FzfLayout) -> Self {
        copy(layout: layout)
    }

    /// Returns a copy that uses reverse layout (display from the top).
    ///
    /// Convenience for ``layout(_:)`` with ``FzfLayout/reverse``.
    /// Maps to `--reverse`.
    ///
    /// - Returns: A new ``Fzf`` value with reverse layout applied.
    public func reverse() -> Self {
        copy(layout: .reverse)
    }

    /// Returns a copy with the given margin around the finder.
    ///
    /// Maps to `--margin=MARGIN`. Accepts TRBL, TB/RL, T/RL/B, or T/R/B/L formats
    /// with optional percentage values.
    ///
    /// - Parameter value: The margin specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func margin(_ value: String) -> Self {
        copy(margin: value)
    }

    /// Returns a copy with the given padding inside the border.
    ///
    /// Maps to `--padding=PADDING`. Only distinguishable from margin when a border is drawn.
    ///
    /// - Parameter value: The padding specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func padding(_ value: String) -> Self {
        copy(padding: value)
    }

    /// Returns a copy that draws a border around the finder with the given style.
    ///
    /// Maps to `--border=STYLE`.
    ///
    /// - Parameter style: The ``FzfBorderStyle`` to use. Pass `nil` for the default
    ///   (`rounded`).
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func border(_ style: FzfBorderStyle? = nil) -> Self {
        copy(border: .some(style))
    }

    /// Returns a copy with a label printed on the border.
    ///
    /// Maps to `--border-label=LABEL`.
    ///
    /// - Parameter value: The label text.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func borderLabel(_ value: String) -> Self {
        copy(borderLabel: value)
    }

    /// Returns a copy with the border label positioned at the given column.
    ///
    /// Maps to `--border-label-pos=N[:top|bottom]`.
    ///
    /// - Parameter value: The position specification.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func borderLabelPos(_ value: String) -> Self {
        copy(borderLabelPos: value)
    }

    // MARK: - List section

    /// Returns a copy that enables multi-select with tab/shift-tab.
    ///
    /// Maps to `--multi` or `--multi=MAX`.
    ///
    /// - Parameter max: Optional maximum number of items that can be selected.
    ///   Pass `nil` for unlimited multi-select.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func multi(_ max: Int? = nil) -> Self {
        copy(multi: .some(max))
    }

    /// Returns a copy that highlights the whole current line.
    ///
    /// Maps to `--highlight-line`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func highlightLine(_ enabled: Bool = true) -> Self {
        copy(highlightLine: enabled)
    }

    /// Returns a copy that enables cyclic scroll.
    ///
    /// Maps to `--cycle`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func cycle(_ enabled: Bool = true) -> Self {
        copy(cycle: enabled)
    }

    /// Returns a copy that enables line wrap with the given mode.
    ///
    /// Maps to `--wrap` or `--wrap=MODE`.
    ///
    /// - Parameter mode: The ``FzfWrapMode`` to use. Pass `nil` for default (`char`).
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func wrap(_ mode: FzfWrapMode? = nil) -> Self {
        copy(wrap: .some(mode))
    }

    /// Returns a copy with the given indicator for wrapped lines.
    ///
    /// Maps to `--wrap-sign=INDICATOR`.
    ///
    /// - Parameter value: The indicator string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func wrapSign(_ value: String) -> Self {
        copy(wrapSign: value)
    }

    /// Returns a copy that disables multi-line display for `--read0` items.
    ///
    /// Maps to `--no-multi-line`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noMultiLine(_ enabled: Bool = true) -> Self {
        copy(noMultiLine: enabled)
    }

    /// Returns a copy that enables raw mode, showing non-matching items dimmed.
    ///
    /// Maps to `--raw`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func raw(_ enabled: Bool = true) -> Self {
        copy(raw: enabled)
    }

    /// Returns a copy that tracks the current selection when the result list updates.
    ///
    /// Maps to `--track`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func track(_ enabled: Bool = true) -> Self {
        copy(track: enabled)
    }

    /// Returns a copy that reverses the order of the input.
    ///
    /// Maps to `--tac`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func tac(_ enabled: Bool = true) -> Self {
        copy(tac: enabled)
    }

    /// Returns a copy that renders empty lines between each item.
    ///
    /// Maps to `--gap` or `--gap=N`.
    ///
    /// - Parameter count: Number of gap lines, or `nil` for the default.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func gap(_ count: Int? = nil) -> Self {
        copy(gap: .some(count))
    }

    /// Returns a copy that keeps the right end of the line visible when it's too long.
    ///
    /// Maps to `--keep-right`. Only effective when the query string is empty.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func keepRight(_ enabled: Bool = true) -> Self {
        copy(keepRight: enabled)
    }

    /// Returns a copy that sets the scroll offset from the top/bottom.
    ///
    /// Maps to `--scroll-off=LINES`.
    ///
    /// - Parameter lines: Number of screen lines to keep above or below.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func scrollOff(_ lines: Int) -> Self {
        copy(scrollOff: lines)
    }

    /// Returns a copy that disables horizontal scroll.
    ///
    /// Maps to `--no-hscroll`.
    ///
    /// - Parameter enabled: `true` to disable hscroll; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noHscroll(_ enabled: Bool = true) -> Self {
        copy(noHscroll: enabled)
    }

    /// Returns a copy that sets the horizontal scroll offset.
    ///
    /// Maps to `--hscroll-off=COLS`.
    ///
    /// - Parameter cols: Number of screen columns to keep to the right of the highlight.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func hscrollOff(_ cols: Int) -> Self {
        copy(hscrollOff: cols)
    }

    /// Returns a copy with the given label characters for jump mode.
    ///
    /// Maps to `--jump-labels=CHARS`.
    ///
    /// - Parameter value: The label characters.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func jumpLabels(_ value: String) -> Self {
        copy(jumpLabels: value)
    }

    /// Returns a copy with the given pointer string for the current line.
    ///
    /// Maps to `--pointer=STR`.
    ///
    /// - Parameter value: The pointer string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func pointer(_ value: String) -> Self {
        copy(pointer: value)
    }

    /// Returns a copy with the given multi-select marker string.
    ///
    /// Maps to `--marker=STR`.
    ///
    /// - Parameter value: The marker string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func marker(_ value: String) -> Self {
        copy(marker: value)
    }

    /// Returns a copy with the given ellipsis string for truncated lines.
    ///
    /// Maps to `--ellipsis=STR`.
    ///
    /// - Parameter value: The ellipsis string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func ellipsis(_ value: String) -> Self {
        copy(ellipsis: value)
    }

    /// Returns a copy with the given tab stop width.
    ///
    /// Maps to `--tabstop=SPACES`.
    ///
    /// - Parameter spaces: Number of spaces per tab character.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func tabstop(_ spaces: Int) -> Self {
        copy(tabstop: spaces)
    }

    /// Returns a copy with the given scrollbar characters.
    ///
    /// Maps to `--scrollbar=CHAR1[CHAR2]`. Pass an empty string to hide the scrollbar.
    ///
    /// - Parameter value: The scrollbar character(s), or `nil` to hide.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func scrollbar(_ value: String?) -> Self {
        copy(scrollbar: .some(value))
    }

    /// Returns a copy that draws a border around the list section.
    ///
    /// Maps to `--list-border=STYLE`.
    ///
    /// - Parameter style: The ``FzfBorderStyle`` to use, or `nil` for the default.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func listBorder(_ style: FzfBorderStyle? = nil) -> Self {
        copy(listBorder: .some(style))
    }

    /// Returns a copy with a label printed on the list border.
    ///
    /// Maps to `--list-label=LABEL`.
    ///
    /// - Parameter value: The label text.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func listLabel(_ value: String) -> Self {
        copy(listLabel: value)
    }

    // MARK: - Input section

    /// Returns a copy that disables and hides the input section.
    ///
    /// Maps to `--no-input`. Queries can still be triggered via the `search` action.
    ///
    /// - Parameter enabled: `true` to hide input; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noInput(_ enabled: Bool = true) -> Self {
        copy(noInput: enabled)
    }

    /// Returns a copy with the given input prompt string.
    ///
    /// Maps to `--prompt=STR`.
    ///
    /// - Parameter value: The prompt string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func prompt(_ value: String) -> Self {
        copy(prompt: value)
    }

    /// Returns a copy that uses the given info line display style.
    ///
    /// Maps to `--info=STYLE`.
    ///
    /// - Parameter style: The ``FzfInfoStyle`` to use.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func info(_ style: FzfInfoStyle) -> Self {
        copy(info: style)
    }

    /// Returns a copy that hides the info line.
    ///
    /// Convenience for ``info(_:)`` with ``FzfInfoStyle/hidden``.
    ///
    /// fzf does not provide a dedicated `--no-info` flag; this emits `--info=hidden`.
    ///
    /// - Parameter enabled: `true` to hide info; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noInfo(_ enabled: Bool = true) -> Self {
        if enabled {
            return copy(info: .hidden)
        }
        return self
    }

    /// Returns a copy with the given separator string on the info line.
    ///
    /// Maps to `--separator=STR`. Pass an empty string to remove the separator.
    ///
    /// - Parameter value: The separator string, or `nil` to remove it.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func separator(_ value: String?) -> Self {
        copy(separator: .some(value))
    }

    /// Returns a copy with ghost text displayed when the input is empty.
    ///
    /// Maps to `--ghost=TEXT`.
    ///
    /// - Parameter value: The ghost text string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func ghost(_ value: String) -> Self {
        copy(ghost: value)
    }

    /// Returns a copy that makes word-wise movements respect path separators.
    ///
    /// Maps to `--filepath-word`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func filepathWord(_ enabled: Bool = true) -> Self {
        copy(filepathWord: enabled)
    }

    /// Returns a copy that draws a border around the input section.
    ///
    /// Maps to `--input-border=STYLE`.
    ///
    /// - Parameter style: The ``FzfBorderStyle`` to use, or `nil` for the default.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func inputBorder(_ style: FzfBorderStyle? = nil) -> Self {
        copy(inputBorder: .some(style))
    }

    /// Returns a copy with a label printed on the input border.
    ///
    /// Maps to `--input-label=LABEL`.
    ///
    /// - Parameter value: The label text.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func inputLabel(_ value: String) -> Self {
        copy(inputLabel: value)
    }

    // MARK: - Preview

    /// Returns a copy that executes the given command as a preview for the current line.
    ///
    /// Maps to `--preview=COMMAND`. The placeholder `{}` is replaced with the current line.
    ///
    /// - Parameter command: The preview command template.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func preview(_ command: String) -> Self {
        copy(preview: command)
    }

    /// Returns a copy that configures the preview window layout and behavior.
    ///
    /// Maps to `--preview-window=SPEC`. Accepts position, size, border style, wrap/follow/cycle
    /// flags, scroll offset, and responsive alternatives.
    ///
    /// - Parameter value: The preview window specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func previewWindow(_ value: String) -> Self {
        copy(previewWindow: value)
    }

    /// Returns a copy that sets the preview window border style.
    ///
    /// Maps to `--preview-border=STYLE`.
    ///
    /// - Parameter style: The ``FzfBorderStyle`` to use, or `nil` for the default.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func previewBorder(_ style: FzfBorderStyle? = nil) -> Self {
        copy(previewBorder: .some(style))
    }

    /// Returns a copy with a label printed on the preview window border.
    ///
    /// Maps to `--preview-label=LABEL`.
    ///
    /// - Parameter value: The label text.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func previewLabel(_ value: String) -> Self {
        copy(previewLabel: value)
    }

    /// Returns a copy with the preview label positioned at the given column.
    ///
    /// Maps to `--preview-label-pos=N[:top|bottom]`.
    ///
    /// - Parameter value: The position specification.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func previewLabelPos(_ value: String) -> Self {
        copy(previewLabelPos: value)
    }

    // MARK: - Header / Footer

    /// Returns a copy with the given string as the sticky header.
    ///
    /// Maps to `--header=STR`. ANSI color codes are processed even without `--ansi`.
    ///
    /// - Parameter value: The header text.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func header(_ value: String) -> Self {
        copy(header: value)
    }

    /// Returns a copy that treats the first N input lines as the sticky header.
    ///
    /// Maps to `--header-lines=N`.
    ///
    /// - Parameter count: Number of header lines.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func headerLines(_ count: Int) -> Self {
        copy(headerLines: count)
    }

    /// Returns a copy that prints the header before the prompt line.
    ///
    /// Maps to `--header-first`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func headerFirst(_ enabled: Bool = true) -> Self {
        copy(headerFirst: enabled)
    }

    /// Returns a copy that draws a border around the header section.
    ///
    /// Maps to `--header-border=STYLE`.
    ///
    /// - Parameter style: The ``FzfBorderStyle`` to use, or `nil` for the default.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func headerBorder(_ style: FzfBorderStyle? = nil) -> Self {
        copy(headerBorder: .some(style))
    }

    /// Returns a copy with the given string as the sticky footer.
    ///
    /// Maps to `--footer=STR`. ANSI color codes are processed even without `--ansi`.
    ///
    /// - Parameter value: The footer text.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func footer(_ value: String) -> Self {
        copy(footer: value)
    }

    /// Returns a copy that draws a border around the footer section.
    ///
    /// Maps to `--footer-border=STYLE`.
    ///
    /// - Parameter style: The ``FzfBorderStyle`` to use, or `nil` for the default.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func footerBorder(_ style: FzfBorderStyle? = nil) -> Self {
        copy(footerBorder: .some(style))
    }

    // MARK: - Scripting

    /// Returns a copy that starts the finder with the given initial query.
    ///
    /// Maps to `--query=STR`.
    ///
    /// - Parameter value: The initial query string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func query(_ value: String) -> Self {
        copy(query: value)
    }

    /// Returns a copy that auto-selects if there is only one match for the initial query.
    ///
    /// Maps to `--select-1`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func select1(_ enabled: Bool = true) -> Self {
        copy(select1: enabled)
    }

    /// Returns a copy that exits immediately if there is no match for the initial query.
    ///
    /// Maps to `--exit-0`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func exit0(_ enabled: Bool = true) -> Self {
        copy(exit0: enabled)
    }

    /// Returns a copy that enables non-interactive filter mode.
    ///
    /// Maps to `--filter=STR`. fzf becomes a fuzzy version of grep — it does not start the
    /// interactive finder, making this the natural choice for ``run()``.
    ///
    /// - Parameter value: The filter query string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func filter(_ value: String) -> Self {
        copy(filterQuery: value)
    }

    /// Returns a copy that prints the query as the first line of output.
    ///
    /// Maps to `--print-query`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func printQuery(_ enabled: Bool = true) -> Self {
        copy(printQuery: enabled)
    }

    /// Returns a copy that enables additional completion keys.
    ///
    /// Maps to `--expect=KEY[,..]`. fzf prints the key pressed as an extra line of output.
    ///
    /// - Parameter value: Comma-separated list of key names.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func expect(_ value: String) -> Self {
        copy(expect: value)
    }

    /// Returns a copy that does not clear the finder interface on exit.
    ///
    /// Maps to `--no-clear`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noClear(_ enabled: Bool = true) -> Self {
        copy(noClear: enabled)
    }

    // MARK: - Key/Event binding

    /// Returns a copy with the given key/event binding appended.
    ///
    /// Maps to `--bind=BINDINGS`. Can be called multiple times; each call appends a separate
    /// `--bind` argument.
    ///
    /// - Parameter value: The binding specification (e.g. `"enter:become(vim {})"`,
    ///   `"ctrl-r:reload(ps -ef)"`).
    /// - Returns: A new ``Fzf`` value with the binding appended.
    public func bind(_ value: String) -> Self {
        copy(bindings: state.bindings + [value])
    }

    // MARK: - Advanced

    /// Returns a copy with the given shell command and flags for child processes.
    ///
    /// Maps to `--with-shell=STR`.
    ///
    /// - Parameter value: The shell command string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func withShell(_ value: String) -> Self {
        copy(withShell: value)
    }

    /// Returns a copy that starts an HTTP server for external control.
    ///
    /// Maps to `--listen=SOCKET_PATH|[ADDR:]PORT`. Pass `nil` for auto port selection.
    ///
    /// - Parameter value: The listen address specification, or `nil` for auto.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func listen(_ value: String? = nil) -> Self {
        copy(listen: .some(value))
    }

    /// Returns a copy that sets the number of matcher threads.
    ///
    /// Maps to `--threads=N`.
    ///
    /// - Parameter count: Number of matcher threads.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func threads(_ count: Int) -> Self {
        copy(threads: count)
    }

    // MARK: - Directory traversal

    /// Returns a copy that configures the built-in directory walker behavior.
    ///
    /// Maps to `--walker=SPEC`. Accepts comma-separated values: `file`, `dir`, `follow`,
    /// `hidden`.
    ///
    /// - Parameter value: The walker specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func walker(_ value: String) -> Self {
        copy(walker: value)
    }

    /// Returns a copy with the given root directories for the built-in walker.
    ///
    /// Maps to `--walker-root=DIR [...]`.
    ///
    /// - Parameter dirs: The root directories to walk.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func walkerRoot(_ dirs: [String]) -> Self {
        copy(walkerRoot: dirs)
    }

    /// Returns a copy with the given directory names to skip during directory walk.
    ///
    /// Maps to `--walker-skip=DIRS`.
    ///
    /// - Parameter value: Comma-separated list of directory names to skip.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func walkerSkip(_ value: String) -> Self {
        copy(walkerSkip: value)
    }

    // MARK: - History

    /// Returns a copy that loads and saves search history from the given file.
    ///
    /// Maps to `--history=HISTORY_FILE`.
    ///
    /// - Parameter path: Path to the history file.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func history(_ path: String) -> Self {
        copy(history: path)
    }

    /// Returns a copy that limits the history file to the given number of entries.
    ///
    /// Maps to `--history-size=N`.
    ///
    /// - Parameter count: Maximum number of entries.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func historySize(_ count: Int) -> Self {
        copy(historySize: count)
    }

    // MARK: - Style and color

    /// Returns a copy that applies the given style preset.
    ///
    /// Maps to `--style=PRESET`. Accepts `default`, `minimal`, or `full`.
    ///
    /// - Parameter value: The style preset name.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func style(_ value: String) -> Self {
        copy(style: value)
    }

    /// Returns a copy with the given color configuration.
    ///
    /// Maps to `--color=SPEC`. Accepts base scheme and/or color name mappings.
    /// Can be called multiple times; each call appends a separate `--color` argument.
    ///
    /// - Parameter value: The color specification string.
    /// - Returns: A new ``Fzf`` value with the option applied.
    public func color(_ value: String) -> Self {
        copy(colors: state.colors + [value])
    }

    /// Returns a copy that disables all colors.
    ///
    /// Maps to `--no-color`.
    ///
    /// - Parameter enabled: `true` to disable colors; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noColor(_ enabled: Bool = true) -> Self {
        copy(noColor: enabled)
    }

    /// Returns a copy that disables bold text.
    ///
    /// Maps to `--no-bold`.
    ///
    /// - Parameter enabled: `true` to disable bold; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noBold(_ enabled: Bool = true) -> Self {
        copy(noBold: enabled)
    }

    /// Returns a copy that uses a black background.
    ///
    /// Maps to `--black`.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func black(_ enabled: Bool = true) -> Self {
        copy(black: enabled)
    }

    // MARK: - Others

    /// Returns a copy that disables mouse support.
    ///
    /// Maps to `--no-mouse`.
    ///
    /// - Parameter enabled: `true` to disable mouse; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noMouse(_ enabled: Bool = true) -> Self {
        copy(noMouse: enabled)
    }

    /// Returns a copy that uses ASCII characters instead of Unicode for drawing.
    ///
    /// Maps to `--no-unicode`.
    ///
    /// - Parameter enabled: `true` to use ASCII; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func noUnicode(_ enabled: Bool = true) -> Self {
        copy(noUnicode: enabled)
    }

    /// Returns a copy that treats ambiguous-width characters as double-width.
    ///
    /// Maps to `--ambidouble`. Set this if your terminal displays box-drawing characters
    /// as 2 columns.
    ///
    /// - Parameter enabled: `true` to enable; `false` to omit. Defaults to `true`.
    /// - Returns: A new ``Fzf`` value with the flag applied.
    public func ambidouble(_ enabled: Bool = true) -> Self {
        copy(ambidouble: enabled)
    }

    // MARK: - Command builder

    /// Builds the raw `fzf` command represented by the current builder state.
    ///
    /// All configured options are assembled into a ``Command`` with the appropriate flags
    /// and arguments. The shared ``ToolConfiguration`` overrides are merged via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        // Search
        if let extended = state.extended {
            arguments.append(extended ? "--extended" : "--no-extended")
        }
        if state.exact { arguments.append("--exact") }
        if state.ignoreCase { arguments.append("--ignore-case") }
        if state.caseSensitive { arguments.append("--no-ignore-case") }
        if state.literal { arguments.append("--literal") }
        if let scheme = state.scheme { arguments.append("--scheme=\(scheme.rawValue)") }
        if let algo = state.algo { arguments.append("--algo=\(algo.rawValue)") }
        if let nth = state.nth { arguments.append("--nth=\(nth)") }
        if let withNth = state.withNth { arguments.append("--with-nth=\(withNth)") }
        if let acceptNth = state.acceptNth { arguments.append("--accept-nth=\(acceptNth)") }
        if state.noSort { arguments.append("--no-sort") }
        if let delimiter = state.delimiter { arguments.append("--delimiter=\(delimiter)") }
        if let tail = state.tail { arguments.append("--tail=\(tail)") }
        if state.disabled { arguments.append("--disabled") }
        if let tiebreak = state.tiebreak { arguments.append("--tiebreak=\(tiebreak)") }

        // Input/Output
        if state.read0 { arguments.append("--read0") }
        if state.print0 { arguments.append("--print0") }
        if state.ansi { arguments.append("--ansi") }
        if state.sync { arguments.append("--sync") }

        // Display mode
        if let height = state.height { arguments.append("--height=\(height)") }
        if let minHeight = state.minHeight { arguments.append("--min-height=\(minHeight)") }
        if let popup = state.popup {
            if let spec = popup {
                arguments.append("--popup=\(spec)")
            } else {
                arguments.append("--popup")
            }
        }

        // Layout
        if let layout = state.layout { arguments.append("--layout=\(layout.rawValue)") }
        if let margin = state.margin { arguments.append("--margin=\(margin)") }
        if let padding = state.padding { arguments.append("--padding=\(padding)") }
        if let border = state.border {
            if let style = border {
                arguments.append("--border=\(style.rawValue)")
            } else {
                arguments.append("--border")
            }
        }
        if let borderLabel = state.borderLabel {
            arguments.append("--border-label=\(borderLabel)")
        }
        if let borderLabelPos = state.borderLabelPos {
            arguments.append("--border-label-pos=\(borderLabelPos)")
        }

        // List section
        if let multi = state.multi {
            if let max = multi {
                arguments.append("--multi=\(max)")
            } else {
                arguments.append("--multi")
            }
        }
        if state.highlightLine { arguments.append("--highlight-line") }
        if state.cycle { arguments.append("--cycle") }
        if let wrap = state.wrap {
            if let mode = wrap {
                arguments.append("--wrap=\(mode.rawValue)")
            } else {
                arguments.append("--wrap")
            }
        }
        if let wrapSign = state.wrapSign { arguments.append("--wrap-sign=\(wrapSign)") }
        if state.noMultiLine { arguments.append("--no-multi-line") }
        if state.raw { arguments.append("--raw") }
        if state.track { arguments.append("--track") }
        if state.tac { arguments.append("--tac") }
        if let gap = state.gap {
            if let count = gap {
                arguments.append("--gap=\(count)")
            } else {
                arguments.append("--gap")
            }
        }
        if state.keepRight { arguments.append("--keep-right") }
        if let scrollOff = state.scrollOff { arguments.append("--scroll-off=\(scrollOff)") }
        if state.noHscroll { arguments.append("--no-hscroll") }
        if let hscrollOff = state.hscrollOff {
            arguments.append("--hscroll-off=\(hscrollOff)")
        }
        if let jumpLabels = state.jumpLabels {
            arguments.append("--jump-labels=\(jumpLabels)")
        }
        if let pointer = state.pointer { arguments.append("--pointer=\(pointer)") }
        if let marker = state.marker { arguments.append("--marker=\(marker)") }
        if let ellipsis = state.ellipsis { arguments.append("--ellipsis=\(ellipsis)") }
        if let tabstop = state.tabstop { arguments.append("--tabstop=\(tabstop)") }
        if let scrollbar = state.scrollbar {
            if let chars = scrollbar {
                arguments.append("--scrollbar=\(chars)")
            } else {
                arguments.append("--no-scrollbar")
            }
        }
        if let listBorder = state.listBorder {
            if let style = listBorder {
                arguments.append("--list-border=\(style.rawValue)")
            } else {
                arguments.append("--list-border")
            }
        }
        if let listLabel = state.listLabel {
            arguments.append("--list-label=\(listLabel)")
        }

        // Input section
        if state.noInput { arguments.append("--no-input") }
        if let prompt = state.prompt { arguments.append("--prompt=\(prompt)") }
        if let info = state.info { arguments.append("--info=\(info.rawValue)") }
        if let separator = state.separator {
            if let value = separator {
                arguments.append("--separator=\(value)")
            } else {
                arguments.append("--no-separator")
            }
        }
        if let ghost = state.ghost { arguments.append("--ghost=\(ghost)") }
        if state.filepathWord { arguments.append("--filepath-word") }
        if let inputBorder = state.inputBorder {
            if let style = inputBorder {
                arguments.append("--input-border=\(style.rawValue)")
            } else {
                arguments.append("--input-border")
            }
        }
        if let inputLabel = state.inputLabel {
            arguments.append("--input-label=\(inputLabel)")
        }

        // Preview
        if let preview = state.preview { arguments.append("--preview=\(preview)") }
        if let previewWindow = state.previewWindow {
            arguments.append("--preview-window=\(previewWindow)")
        }
        if let previewBorder = state.previewBorder {
            if let style = previewBorder {
                arguments.append("--preview-border=\(style.rawValue)")
            } else {
                arguments.append("--preview-border")
            }
        }
        if let previewLabel = state.previewLabel {
            arguments.append("--preview-label=\(previewLabel)")
        }
        if let previewLabelPos = state.previewLabelPos {
            arguments.append("--preview-label-pos=\(previewLabelPos)")
        }

        // Header / Footer
        if let header = state.header { arguments.append("--header=\(header)") }
        if let headerLines = state.headerLines {
            arguments.append("--header-lines=\(headerLines)")
        }
        if state.headerFirst { arguments.append("--header-first") }
        if let headerBorder = state.headerBorder {
            if let style = headerBorder {
                arguments.append("--header-border=\(style.rawValue)")
            } else {
                arguments.append("--header-border")
            }
        }
        if let footer = state.footer { arguments.append("--footer=\(footer)") }
        if let footerBorder = state.footerBorder {
            if let style = footerBorder {
                arguments.append("--footer-border=\(style.rawValue)")
            } else {
                arguments.append("--footer-border")
            }
        }

        // Scripting
        if let query = state.query { arguments.append("--query=\(query)") }
        if state.select1 { arguments.append("--select-1") }
        if state.exit0 { arguments.append("--exit-0") }
        if let filterQuery = state.filterQuery {
            arguments.append("--filter=\(filterQuery)")
        }
        if state.printQuery { arguments.append("--print-query") }
        if let expect = state.expect { arguments.append("--expect=\(expect)") }
        if state.noClear { arguments.append("--no-clear") }

        // Bindings
        for binding in state.bindings {
            arguments.append("--bind=\(binding)")
        }

        // Advanced
        if let withShell = state.withShell {
            arguments.append("--with-shell=\(withShell)")
        }
        if let listen = state.listen {
            if let addr = listen {
                arguments.append("--listen=\(addr)")
            } else {
                arguments.append("--listen")
            }
        }
        if let threads = state.threads { arguments.append("--threads=\(threads)") }

        // Directory traversal
        if let walker = state.walker { arguments.append("--walker=\(walker)") }
        if let walkerRoot = state.walkerRoot {
            for dir in walkerRoot {
                arguments.append("--walker-root=\(dir)")
            }
        }
        if let walkerSkip = state.walkerSkip {
            arguments.append("--walker-skip=\(walkerSkip)")
        }

        // History
        if let history = state.history { arguments.append("--history=\(history)") }
        if let historySize = state.historySize {
            arguments.append("--history-size=\(historySize)")
        }

        // Style and color
        if let style = state.style { arguments.append("--style=\(style)") }
        for colorSpec in state.colors {
            arguments.append("--color=\(colorSpec)")
        }
        if state.noColor { arguments.append("--no-color") }
        if state.noBold { arguments.append("--no-bold") }
        if state.black { arguments.append("--black") }

        // Others
        if state.noMouse { arguments.append("--no-mouse") }
        if state.noUnicode { arguments.append("--no-unicode") }
        if state.ambidouble { arguments.append("--ambidouble") }

        let base = Command("fzf")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    // swiftlint:disable function_parameter_count
    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        // Search
        extended: Bool?? = nil,
        exact: Bool? = nil,
        ignoreCase: Bool? = nil,
        caseSensitive: Bool? = nil,
        literal: Bool? = nil,
        scheme: FzfScheme?? = nil,
        algo: FzfAlgo?? = nil,
        nth: String?? = nil,
        withNth: String?? = nil,
        acceptNth: String?? = nil,
        noSort: Bool? = nil,
        delimiter: String?? = nil,
        tail: Int?? = nil,
        disabled: Bool? = nil,
        tiebreak: String?? = nil,
        // I/O
        read0: Bool? = nil,
        print0: Bool? = nil,
        ansi: Bool? = nil,
        sync: Bool? = nil,
        // Display mode
        height: String?? = nil,
        minHeight: String?? = nil,
        popup: String??? = nil,
        // Layout
        layout: FzfLayout?? = nil,
        margin: String?? = nil,
        padding: String?? = nil,
        border: FzfBorderStyle??? = nil,
        borderLabel: String?? = nil,
        borderLabelPos: String?? = nil,
        // List section
        multi: Int??? = nil,
        highlightLine: Bool? = nil,
        cycle: Bool? = nil,
        wrap: FzfWrapMode??? = nil,
        wrapSign: String?? = nil,
        noMultiLine: Bool? = nil,
        raw: Bool? = nil,
        track: Bool? = nil,
        tac: Bool? = nil,
        gap: Int??? = nil,
        keepRight: Bool? = nil,
        scrollOff: Int?? = nil,
        noHscroll: Bool? = nil,
        hscrollOff: Int?? = nil,
        jumpLabels: String?? = nil,
        pointer: String?? = nil,
        marker: String?? = nil,
        ellipsis: String?? = nil,
        tabstop: Int?? = nil,
        scrollbar: String??? = nil,
        listBorder: FzfBorderStyle??? = nil,
        listLabel: String?? = nil,
        // Input section
        noInput: Bool? = nil,
        prompt: String?? = nil,
        info: FzfInfoStyle?? = nil,
        separator: String??? = nil,
        ghost: String?? = nil,
        filepathWord: Bool? = nil,
        inputBorder: FzfBorderStyle??? = nil,
        inputLabel: String?? = nil,
        // Preview
        preview: String?? = nil,
        previewWindow: String?? = nil,
        previewBorder: FzfBorderStyle??? = nil,
        previewLabel: String?? = nil,
        previewLabelPos: String?? = nil,
        // Header / Footer
        header: String?? = nil,
        headerLines: Int?? = nil,
        headerFirst: Bool? = nil,
        headerBorder: FzfBorderStyle??? = nil,
        footer: String?? = nil,
        footerBorder: FzfBorderStyle??? = nil,
        // Scripting
        query: String?? = nil,
        select1: Bool? = nil,
        exit0: Bool? = nil,
        filterQuery: String?? = nil,
        printQuery: Bool? = nil,
        expect: String?? = nil,
        noClear: Bool? = nil,
        // Binding
        bindings: [String]? = nil,
        // Advanced
        withShell: String?? = nil,
        listen: String??? = nil,
        threads: Int?? = nil,
        // Directory traversal
        walker: String?? = nil,
        walkerRoot: [String]?? = nil,
        walkerSkip: String?? = nil,
        // History
        history: String?? = nil,
        historySize: Int?? = nil,
        // Style and color
        style: String?? = nil,
        colors: [String]? = nil,
        noColor: Bool? = nil,
        noBold: Bool? = nil,
        black: Bool? = nil,
        // Others
        noMouse: Bool? = nil,
        noUnicode: Bool? = nil,
        ambidouble: Bool? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                extended: extended ?? state.extended,
                exact: exact ?? state.exact,
                ignoreCase: ignoreCase ?? state.ignoreCase,
                caseSensitive: caseSensitive ?? state.caseSensitive,
                literal: literal ?? state.literal,
                scheme: scheme ?? state.scheme,
                algo: algo ?? state.algo,
                nth: nth ?? state.nth,
                withNth: withNth ?? state.withNth,
                acceptNth: acceptNth ?? state.acceptNth,
                noSort: noSort ?? state.noSort,
                delimiter: delimiter ?? state.delimiter,
                tail: tail ?? state.tail,
                disabled: disabled ?? state.disabled,
                tiebreak: tiebreak ?? state.tiebreak,
                read0: read0 ?? state.read0,
                print0: print0 ?? state.print0,
                ansi: ansi ?? state.ansi,
                sync: sync ?? state.sync,
                height: height ?? state.height,
                minHeight: minHeight ?? state.minHeight,
                popup: popup ?? state.popup,
                layout: layout ?? state.layout,
                margin: margin ?? state.margin,
                padding: padding ?? state.padding,
                border: border ?? state.border,
                borderLabel: borderLabel ?? state.borderLabel,
                borderLabelPos: borderLabelPos ?? state.borderLabelPos,
                multi: multi ?? state.multi,
                highlightLine: highlightLine ?? state.highlightLine,
                cycle: cycle ?? state.cycle,
                wrap: wrap ?? state.wrap,
                wrapSign: wrapSign ?? state.wrapSign,
                noMultiLine: noMultiLine ?? state.noMultiLine,
                raw: raw ?? state.raw,
                track: track ?? state.track,
                tac: tac ?? state.tac,
                gap: gap ?? state.gap,
                keepRight: keepRight ?? state.keepRight,
                scrollOff: scrollOff ?? state.scrollOff,
                noHscroll: noHscroll ?? state.noHscroll,
                hscrollOff: hscrollOff ?? state.hscrollOff,
                jumpLabels: jumpLabels ?? state.jumpLabels,
                pointer: pointer ?? state.pointer,
                marker: marker ?? state.marker,
                ellipsis: ellipsis ?? state.ellipsis,
                tabstop: tabstop ?? state.tabstop,
                scrollbar: scrollbar ?? state.scrollbar,
                listBorder: listBorder ?? state.listBorder,
                listLabel: listLabel ?? state.listLabel,
                noInput: noInput ?? state.noInput,
                prompt: prompt ?? state.prompt,
                info: info ?? state.info,
                separator: separator ?? state.separator,
                ghost: ghost ?? state.ghost,
                filepathWord: filepathWord ?? state.filepathWord,
                inputBorder: inputBorder ?? state.inputBorder,
                inputLabel: inputLabel ?? state.inputLabel,
                preview: preview ?? state.preview,
                previewWindow: previewWindow ?? state.previewWindow,
                previewBorder: previewBorder ?? state.previewBorder,
                previewLabel: previewLabel ?? state.previewLabel,
                previewLabelPos: previewLabelPos ?? state.previewLabelPos,
                header: header ?? state.header,
                headerLines: headerLines ?? state.headerLines,
                headerFirst: headerFirst ?? state.headerFirst,
                headerBorder: headerBorder ?? state.headerBorder,
                footer: footer ?? state.footer,
                footerBorder: footerBorder ?? state.footerBorder,
                query: query ?? state.query,
                select1: select1 ?? state.select1,
                exit0: exit0 ?? state.exit0,
                filterQuery: filterQuery ?? state.filterQuery,
                printQuery: printQuery ?? state.printQuery,
                expect: expect ?? state.expect,
                noClear: noClear ?? state.noClear,
                bindings: bindings ?? state.bindings,
                withShell: withShell ?? state.withShell,
                listen: listen ?? state.listen,
                threads: threads ?? state.threads,
                walker: walker ?? state.walker,
                walkerRoot: walkerRoot ?? state.walkerRoot,
                walkerSkip: walkerSkip ?? state.walkerSkip,
                history: history ?? state.history,
                historySize: historySize ?? state.historySize,
                style: style ?? state.style,
                colors: colors ?? state.colors,
                noColor: noColor ?? state.noColor,
                noBold: noBold ?? state.noBold,
                black: black ?? state.black,
                noMouse: noMouse ?? state.noMouse,
                noUnicode: noUnicode ?? state.noUnicode,
                ambidouble: ambidouble ?? state.ambidouble
            )
        )
    }
}

// MARK: - Private State

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination

    // Search
    let extended: Bool?
    let exact: Bool
    let ignoreCase: Bool
    let caseSensitive: Bool
    let literal: Bool
    let scheme: FzfScheme?
    let algo: FzfAlgo?
    let nth: String?
    let withNth: String?
    let acceptNth: String?
    let noSort: Bool
    let delimiter: String?
    let tail: Int?
    let disabled: Bool
    let tiebreak: String?

    // I/O
    let read0: Bool
    let print0: Bool
    let ansi: Bool
    let sync: Bool

    // Display mode
    let height: String?
    let minHeight: String?
    let popup: String??

    // Layout
    let layout: FzfLayout?
    let margin: String?
    let padding: String?
    let border: FzfBorderStyle??
    let borderLabel: String?
    let borderLabelPos: String?

    // List section
    let multi: Int??
    let highlightLine: Bool
    let cycle: Bool
    let wrap: FzfWrapMode??
    let wrapSign: String?
    let noMultiLine: Bool
    let raw: Bool
    let track: Bool
    let tac: Bool
    let gap: Int??
    let keepRight: Bool
    let scrollOff: Int?
    let noHscroll: Bool
    let hscrollOff: Int?
    let jumpLabels: String?
    let pointer: String?
    let marker: String?
    let ellipsis: String?
    let tabstop: Int?
    let scrollbar: String??
    let listBorder: FzfBorderStyle??
    let listLabel: String?

    // Input section
    let noInput: Bool
    let prompt: String?
    let info: FzfInfoStyle?
    let separator: String??
    let ghost: String?
    let filepathWord: Bool
    let inputBorder: FzfBorderStyle??
    let inputLabel: String?

    // Preview
    let preview: String?
    let previewWindow: String?
    let previewBorder: FzfBorderStyle??
    let previewLabel: String?
    let previewLabelPos: String?

    // Header / Footer
    let header: String?
    let headerLines: Int?
    let headerFirst: Bool
    let headerBorder: FzfBorderStyle??
    let footer: String?
    let footerBorder: FzfBorderStyle??

    // Scripting
    let query: String?
    let select1: Bool
    let exit0: Bool
    let filterQuery: String?
    let printQuery: Bool
    let expect: String?
    let noClear: Bool

    // Binding
    let bindings: [String]

    // Advanced
    let withShell: String?
    let listen: String??
    let threads: Int?

    // Directory traversal
    let walker: String?
    let walkerRoot: [String]?
    let walkerSkip: String?

    // History
    let history: String?
    let historySize: Int?

    // Style and color
    let style: String?
    let colors: [String]
    let noColor: Bool
    let noBold: Bool
    let black: Bool

    // Others
    let noMouse: Bool
    let noUnicode: Bool
    let ambidouble: Bool

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        extended: Bool? = nil,
        exact: Bool = false,
        ignoreCase: Bool = false,
        caseSensitive: Bool = false,
        literal: Bool = false,
        scheme: FzfScheme? = nil,
        algo: FzfAlgo? = nil,
        nth: String? = nil,
        withNth: String? = nil,
        acceptNth: String? = nil,
        noSort: Bool = false,
        delimiter: String? = nil,
        tail: Int? = nil,
        disabled: Bool = false,
        tiebreak: String? = nil,
        read0: Bool = false,
        print0: Bool = false,
        ansi: Bool = false,
        sync: Bool = false,
        height: String? = nil,
        minHeight: String? = nil,
        popup: String?? = nil,
        layout: FzfLayout? = nil,
        margin: String? = nil,
        padding: String? = nil,
        border: FzfBorderStyle?? = nil,
        borderLabel: String? = nil,
        borderLabelPos: String? = nil,
        multi: Int?? = nil,
        highlightLine: Bool = false,
        cycle: Bool = false,
        wrap: FzfWrapMode?? = nil,
        wrapSign: String? = nil,
        noMultiLine: Bool = false,
        raw: Bool = false,
        track: Bool = false,
        tac: Bool = false,
        gap: Int?? = nil,
        keepRight: Bool = false,
        scrollOff: Int? = nil,
        noHscroll: Bool = false,
        hscrollOff: Int? = nil,
        jumpLabels: String? = nil,
        pointer: String? = nil,
        marker: String? = nil,
        ellipsis: String? = nil,
        tabstop: Int? = nil,
        scrollbar: String?? = nil,
        listBorder: FzfBorderStyle?? = nil,
        listLabel: String? = nil,
        noInput: Bool = false,
        prompt: String? = nil,
        info: FzfInfoStyle? = nil,
        separator: String?? = nil,
        ghost: String? = nil,
        filepathWord: Bool = false,
        inputBorder: FzfBorderStyle?? = nil,
        inputLabel: String? = nil,
        preview: String? = nil,
        previewWindow: String? = nil,
        previewBorder: FzfBorderStyle?? = nil,
        previewLabel: String? = nil,
        previewLabelPos: String? = nil,
        header: String? = nil,
        headerLines: Int? = nil,
        headerFirst: Bool = false,
        headerBorder: FzfBorderStyle?? = nil,
        footer: String? = nil,
        footerBorder: FzfBorderStyle?? = nil,
        query: String? = nil,
        select1: Bool = false,
        exit0: Bool = false,
        filterQuery: String? = nil,
        printQuery: Bool = false,
        expect: String? = nil,
        noClear: Bool = false,
        bindings: [String] = [],
        withShell: String? = nil,
        listen: String?? = nil,
        threads: Int? = nil,
        walker: String? = nil,
        walkerRoot: [String]? = nil,
        walkerSkip: String? = nil,
        history: String? = nil,
        historySize: Int? = nil,
        style: String? = nil,
        colors: [String] = [],
        noColor: Bool = false,
        noBold: Bool = false,
        black: Bool = false,
        noMouse: Bool = false,
        noUnicode: Bool = false,
        ambidouble: Bool = false
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.extended = extended
        self.exact = exact
        self.ignoreCase = ignoreCase
        self.caseSensitive = caseSensitive
        self.literal = literal
        self.scheme = scheme
        self.algo = algo
        self.nth = nth
        self.withNth = withNth
        self.acceptNth = acceptNth
        self.noSort = noSort
        self.delimiter = delimiter
        self.tail = tail
        self.disabled = disabled
        self.tiebreak = tiebreak
        self.read0 = read0
        self.print0 = print0
        self.ansi = ansi
        self.sync = sync
        self.height = height
        self.minHeight = minHeight
        self.popup = popup
        self.layout = layout
        self.margin = margin
        self.padding = padding
        self.border = border
        self.borderLabel = borderLabel
        self.borderLabelPos = borderLabelPos
        self.multi = multi
        self.highlightLine = highlightLine
        self.cycle = cycle
        self.wrap = wrap
        self.wrapSign = wrapSign
        self.noMultiLine = noMultiLine
        self.raw = raw
        self.track = track
        self.tac = tac
        self.gap = gap
        self.keepRight = keepRight
        self.scrollOff = scrollOff
        self.noHscroll = noHscroll
        self.hscrollOff = hscrollOff
        self.jumpLabels = jumpLabels
        self.pointer = pointer
        self.marker = marker
        self.ellipsis = ellipsis
        self.tabstop = tabstop
        self.scrollbar = scrollbar
        self.listBorder = listBorder
        self.listLabel = listLabel
        self.noInput = noInput
        self.prompt = prompt
        self.info = info
        self.separator = separator
        self.ghost = ghost
        self.filepathWord = filepathWord
        self.inputBorder = inputBorder
        self.inputLabel = inputLabel
        self.preview = preview
        self.previewWindow = previewWindow
        self.previewBorder = previewBorder
        self.previewLabel = previewLabel
        self.previewLabelPos = previewLabelPos
        self.header = header
        self.headerLines = headerLines
        self.headerFirst = headerFirst
        self.headerBorder = headerBorder
        self.footer = footer
        self.footerBorder = footerBorder
        self.query = query
        self.select1 = select1
        self.exit0 = exit0
        self.filterQuery = filterQuery
        self.printQuery = printQuery
        self.expect = expect
        self.noClear = noClear
        self.bindings = bindings
        self.withShell = withShell
        self.listen = listen
        self.threads = threads
        self.walker = walker
        self.walkerRoot = walkerRoot
        self.walkerSkip = walkerSkip
        self.history = history
        self.historySize = historySize
        self.style = style
        self.colors = colors
        self.noColor = noColor
        self.noBold = noBold
        self.black = black
        self.noMouse = noMouse
        self.noUnicode = noUnicode
        self.ambidouble = ambidouble
    }
}
#endif
