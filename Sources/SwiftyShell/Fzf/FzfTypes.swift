#if Fzf

/// The scoring scheme used by `fzf` to rank matches.
///
/// Different schemes are optimized for different types of input. Use ``path`` for file paths,
/// ``history`` for command history, and ``default`` for general-purpose fuzzy matching.
public enum FzfScheme: String, Sendable, Equatable, Hashable {
    /// Generic scoring scheme designed to work well with any type of input.
    case `default`

    /// Scoring scheme optimized for file paths, giving bonus points after path separators.
    case path

    /// Scoring scheme suited for command history where chronological ordering matters.
    case history
}

/// The fuzzy matching algorithm used by `fzf`.
///
/// ``v2`` produces optimal results but is slightly slower; ``v1`` is faster but may miss
/// the highest-scoring match.
public enum FzfAlgo: String, Sendable, Equatable, Hashable {
    /// Optimal scoring algorithm (quality). This is the default.
    case v2

    /// Faster but not guaranteed to find the optimal result (performance).
    case v1
}

/// The layout direction for the `fzf` finder interface.
///
/// Controls whether the prompt and results are displayed from the top or bottom of the
/// available screen area.
public enum FzfLayout: String, Sendable, Equatable, Hashable {
    /// Display from the bottom of the screen. This is the default.
    case `default`

    /// Display from the top of the screen.
    case reverse

    /// Display from the top of the screen with the prompt at the bottom.
    case reverseList = "reverse-list"
}

/// The border drawing style for `fzf` window elements.
///
/// Used with ``Fzf/border(_:)``, ``Fzf/listBorder(_:)``, ``Fzf/inputBorder(_:)``,
/// ``Fzf/previewBorder(_:)``, ``Fzf/headerBorder(_:)``, and ``Fzf/footerBorder(_:)``.
public enum FzfBorderStyle: String, Sendable, Equatable, Hashable {
    /// Border with rounded corners.
    case rounded

    /// Border with sharp corners.
    case sharp

    /// Border with bold lines.
    case bold

    /// Border with double lines.
    case double

    /// Border with dashed lines and rounded corners.
    case dashed

    /// Border using block elements; suitable for different background colors.
    case block

    /// Border using legacy computing symbols; may not render on some terminals.
    case thinblock

    /// Horizontal lines above and below the finder.
    case horizontal

    /// Vertical lines on each side of the finder.
    case vertical

    /// Single line border with position automatically determined.
    case line

    /// Border line on the top only.
    case top

    /// Border line on the bottom only.
    case bottom

    /// Border line on the left only.
    case left

    /// Border line on the right only.
    case right

    /// No border.
    case none
}

/// The display style for the `fzf` info line showing match counters and loading indicators.
///
/// Controls where and how the match count and other status information appear in the interface.
public enum FzfInfoStyle: Sendable, Equatable, Hashable {
    /// Display on the left end of the horizontal separator. This is the default.
    case `default`

    /// Display on the right end of the horizontal separator.
    case right

    /// Do not display finder info.
    case hidden

    /// Display after the prompt with an optional custom prefix.
    ///
    /// - Parameter prefix: The prefix string between the prompt and info. Pass `nil` for
    ///   the default prefix `" < "`.
    case inline(prefix: String? = nil)

    /// Display on the right end of the prompt line with an optional custom prefix.
    ///
    /// - Parameter prefix: The prefix string before the info text. Pass `nil` for no prefix.
    case inlineRight(prefix: String? = nil)

    /// The raw string value passed to `--info`.
    var rawValue: String {
        switch self {
        case .default: return "default"
        case .right: return "right"
        case .hidden: return "hidden"
        case let .inline(prefix):
            if let prefix { return "inline:\(prefix)" }
            return "inline"
        case let .inlineRight(prefix):
            if let prefix { return "inline-right:\(prefix)" }
            return "inline-right"
        }
    }
}

/// The line wrapping mode for `fzf` list items.
///
/// Controls whether long lines wrap at character boundaries or word boundaries.
public enum FzfWrapMode: String, Sendable, Equatable, Hashable {
    /// Wrap at arbitrary character positions. This is the default when wrapping is enabled.
    case char

    /// Wrap at word boundaries (spaces and tabs).
    case word
}
#endif
