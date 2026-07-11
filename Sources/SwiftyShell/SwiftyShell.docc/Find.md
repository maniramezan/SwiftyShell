# ``Find``

Traverse file trees with typed, portable predicates and actions.

``Find`` models the common subset of the current macOS/BSD and GNU `find`
implementations. Every root, pattern, operator, and action is passed as a separate
argv element, so spaces and shell metacharacters remain literal. The API does not
expose `-exec`, `-execdir`, or raw expression strings.

```swift
let swiftFiles = try await Find(context: context)
    .root("Sources")
    .expression(
        FindExpression.name("*.swift")
            .and(.type(.regularFile))
            .and(.minimumDepth(1))
            .and(.maximumDepth(4))
            .and(.print)
    )
    .run()
```

Compose alternatives and negation as typed expression nodes. Parentheses and
explicit `-and` or `-or` tokens are generated automatically, preserving the
expression tree without relying on platform-specific precedence shortcuts.

```swift
let sourceOrManifest = FindExpression.path("*/Sources/*.swift")
    .or(.name("Package.swift"))
    .and(.path("*/Generated/*").negated())
    .and(.print0)

let output = try await Find(context: context)
    .roots(["Package.swift", "Sources"])
    .expression(sourceOrManifest)
    .run()
```

Use ``FindExpression/print0`` when names may contain whitespace or newlines.
Relative roots beginning with `-`, `!`, or `(` are automatically prefixed with
`./`. BSD's `-f` root option is not available in GNU `find`; qualification is the
portable approach documented by GNU and accepted by macOS/BSD.

## Topics

### Building Searches

- ``init(context:)``
- ``root(_:)``
- ``roots(_:)``
- ``expression(_:)``
- ``command()``

### Expressions

- ``FindExpression``
- ``FindFileType``
- ``FindExpression/name(_:)``
- ``FindExpression/path(_:)``
- ``FindExpression/type(_:)``
- ``FindExpression/minimumDepth(_:)``
- ``FindExpression/maximumDepth(_:)``
- ``FindExpression/and(_:)``
- ``FindExpression/or(_:)``
- ``FindExpression/negated()``
- ``FindExpression/print``
- ``FindExpression/print0``
