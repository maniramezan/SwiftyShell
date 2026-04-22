# ``MockExecutor``

A test-double implementation of ``CommandExecutor`` that returns caller-controlled responses without spawning real processes.

## Topics

### Creating a Mock Executor

- ``init(handler:)``
- ``init(stdout:stderr:exitCode:)``

### Executing

- ``execute(_:in:)-swift.method``
- ``execute(_:in:)-swift.pipeline``

### Related Types

- ``CommandExecutor``
- ``ShellContext``
- ``ShellOutput``
