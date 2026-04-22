# SwiftyShell — Agent Instructions

This file is maintainer-oriented automation guidance for Claude-style assistants. It is public for transparency and collaboration, but it is optional and not required for normal contribution workflows.

The canonical agent guide for this project is **[`AGENTS.md`](AGENTS.md)**.

**Read `AGENTS.md` now** to load the full repository layout, build commands, coding
conventions, documentation rules, and architecture reference before assisting with
any task in this repository.

If the task involves generating SwiftyShell code, changing public API, or authoring
command families, also read `.claude/skills/swiftyshell.md`. `AGENTS.md` and
`.claude/skills/swiftyshell.md` must be kept aligned and updated together when the
shared agent guidance changes.

## Hard Gate — Do Not Finish Without Both

Before you mark any task complete or hand back to the user, both of the following must pass on every file you added or modified:

1. **`swift test`** — all tests green.
2. **`swift-format lint --strict`** — no errors on the files you touched. Run `swift-format format -i <file>` on new Swift to auto-fix, then re-lint.

This applies to every kind of change, including tests, docs with Swift snippets, new command families, and bug fixes. If a lint rule is wrong for a specific construct, update `.swift-format` in the same change — do not bypass the gate.
