# ``ShellError``

Errors thrown while building workflows or running shell commands.

## Topics

### Configuration Errors

- ``invalidConfiguration(description:)``

### Execution Errors

- ``commandNotFound(_:)``
- ``exitFailure(command:output:)``
- ``spawnError(command:reason:)``

### Resource Errors

- ``timeout(command:duration:partialOutput:)``
- ``outputLimitExceeded(command:limit:partialOutput:)``

### Stream Errors

- ``decodingError(command:stream:)``

### Task Errors

- ``cancelled(command:partialOutput:)``

### Workflow Errors

- ``workflowConditionFailed(description:)``

### Related Types

- ``StreamKind``
