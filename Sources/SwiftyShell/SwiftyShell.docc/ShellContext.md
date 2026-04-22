# ``ShellContext``

Default execution settings shared by commands and pipelines.

## Topics

### Creating a Context

- ``init(executor:searchPaths:environment:workingDirectory:defaultTimeout:defaultOutputLimit:)``

### Resolving Search Paths

- ``defaultSearchPaths``
- ``defaultSearchPaths(environment:platform:)``

### Inspecting a Context

- ``executor``
- ``searchPaths``
- ``environment``
- ``workingDirectory``
- ``defaultTimeout``
- ``defaultOutputLimit``

### Related Types

- ``ShellPlatform``
- ``CommandExecutor``
- ``SubprocessExecutor``
- ``MockExecutor``
