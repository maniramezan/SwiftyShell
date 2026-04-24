# ``Workflow``

A reusable asynchronous workflow that can be transformed and composed.

## Topics

### Running

- ``run()``

### Transforming

- ``map(_:)-((Value)->T)``
- ``map(_:)-(KeyPath<Value,T>)``
- ``flatMap(_:)``
- ``then(_:)``

### Gating

- ``require(_:else:)-swift.method``
- ``require(_:equals:else:)``

### Creating

- ``init(_:)``
