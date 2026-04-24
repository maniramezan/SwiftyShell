# ``MockExecutor``

A test-double implementation of ``CommandExecutor`` that returns caller-controlled responses without spawning real processes.

## Topics

### Creating a Mock Executor

- ``init(handler:)``
- ``init(stdout:stderr:exitCode:)``

### Executing

- ``execute(_:in:)-(Command,_)``
- ``execute(_:in:)-(Pipeline,_)``

### Related Types

- ``CommandExecutor``
- ``ShellOutput``
