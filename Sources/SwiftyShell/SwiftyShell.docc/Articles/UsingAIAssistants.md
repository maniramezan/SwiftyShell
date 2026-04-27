# Using AI Assistants

Generate correct SwiftyShell code and add new command families using the bundled agent skill.

## Overview

SwiftyShell ships a machine-readable skill file at `.claude/skills/swiftyshell.md`. This file contains the complete public API reference, code-generation rules, documentation requirements, and command-family authoring conventions in a format that AI coding assistants — Claude, Codex, and compatible tools — can load into their working context.

The skill serves two purposes:

1. **Generating SwiftyShell code** from a plain-language task description
2. **Adding new command families** following established project conventions

## Loading the Skill

The skill lives at `.claude/skills/swiftyshell.md` and is symlinked from `.codex/skills/swiftyshell.md`, so both Claude and Codex agents resolve the same file — there is only one copy on disk.

**Claude Code** loads the skill automatically when you open this repository (the path is referenced from `CLAUDE.md`). You can also invoke it explicitly with a slash command if your session has skills configured.

**Codex** picks it up via `.codex/skills/swiftyshell.md`. Point Codex at this repository and the skill is available without any additional setup.

Once loaded, describe the shell task you want to perform:

> "I need to check that a git repo's working tree is clean before running a deploy script. If it has uncommitted changes, the deploy should abort."

The assistant will generate typed SwiftyShell code using the correct APIs:

```swift
do {
    try await Git(context: context)
        .workingDirectory(repoPath)
        .status()
        .require(\.state, equals: .noChanges, else: DeployError.dirtyWorkingTree)
        .run()
} catch ShellError.workflowConditionFailed {
    throw DeployError.dirtyWorkingTree
}
```

## Code Generation Rules the Skill Enforces

The skill instills a decision tree for type selection. Given a task, the assistant:

1. Reaches for a typed wrapper (`Git`, `Grep`, `Brew`, file-system commands) before falling back to a raw `Command`
2. Chains typed results instead of parsing raw strings
3. Uses `async let` and `TaskGroup` for operations that can run concurrently
4. Writes `MockExecutor`-based unit tests rather than spawning real processes
5. Adds `///` doc comments on every `public` declaration it creates
6. Passes an explicit `ShellContext` rather than relying on default `.init()` calls

## Adding a New Command Family

Describe the tool you want wrapped:

> "I want a typed wrapper for the `rsync` command. It should support a `--delete` flag, source and destination paths, and the common SwiftyShell configuration overrides."

The assistant will produce a complete `struct` conforming to ``RunnableCommandFamily``, private `State`, fluent builder methods, a `command()` implementation, and a test suite — all following the conventions in <doc:BuildingCommandFamilies>.

## Prompt Tips

| Goal | Effective prompt style |
|---|---|
| Generate a one-off command | "Run `make release` and capture both stdout and stderr to `/tmp/build.log`" |
| Generate a typed workflow | "Check if the working tree is clean, then fetch from origin" |
| Add a command family | "Add a typed wrapper for `terraform` with `init`, `plan`, `apply`, and `destroy` subcommands" |
| Test an existing family | "Write unit tests for `Brew` that verify the `--greedy` flag appears in the command arguments" |
| Debug a generated result | "The generated `Grep` call returns no results — help me check the pattern and file path" |

Keep prompts concrete: include the tool name, the flags you need, and what the result should look like. The skill knows the SwiftyShell API, so you do not need to repeat type names or method signatures unless you are asking about something unusual.

## Keeping the Skill Up to Date

The skill file must reflect the *implemented* API, not the spec. Whenever you:

- Add a new typed command family or method
- Change a method signature
- Add or rename a `ShellError` case
- Change execution semantics

…update `.claude/skills/swiftyshell.md` and `AGENTS.md` in the same pull request. Because `.codex/skills/swiftyshell.md` is a symlink to that file, both Claude and Codex pick up the change automatically. The skill's maintenance section explains the exact checklist.

## Related

- <doc:BuildingCommandFamilies> — the canonical guide to adding a command family manually
- <doc:GettingStarted> — hands-on introduction to SwiftyShell
