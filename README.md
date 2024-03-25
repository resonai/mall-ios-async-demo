# Mall iOS Async Demo
This is an example implementation of the Mall on iOS using Structured Concurrency. 

## Implementation
The whole implementation relies on the `actor MallNode`:
```swift
actor MallNode<Value: Sendable> {
    private(set) var value: Value
    private var continuations: [AsyncStream<Value>.Continuation] = []

    func subscribe() -> AsyncStream<Value> {
        AsyncStream { continuation in
            continuation.yield(value)
            self.continuations.append(continuation)
        }
    }

    init(_ value: Value) {
        self.value = value
    }

    func send(_ value: Value) {
        self.value = value
        for continuation in continuations {
            continuation.yield(value)
        }
    }
}
```
Since you cannot `multicast` an `AsyncStream` yet, the Node has a `subscribe()` function which creates a new stream every time a subscriber needs to be added.
In rest, the Async Mall has the same semantics as the Combine Mall, except lacks all the generated code, so now it only works with 1/2 inputs, and 1 output.

## Example
The app provides a test implementation of the Mall containing 300 nodes, and running sequentially. It starts with 1 trigger which updates 2 nodes, which are then zipped to update the 3rd node, and the cycle repeats:
```swift
op {
    b0>!

    Self.push1

    ~>b1
}

op {
    b0>!

    Self.push1

    ~>b2
}

op {
    b1>%
    b2>%

    Self.push

    ~>b3
}

op {
    b3>!

    Self.push1

    ~>b4
}

...
```

## Results
One the above example provided:
* **Combine Mall**: ~3-10ms to execute
* **Async Mall**: ~8-20ms to execute

## Benefits
* Supports non-optional out-the-box
* Pushes can be `await`ed

## Known Issues
* The Mall still doesn't enforce any order of execution
* Reads of the same node that resulted in the trigger are not guaranteed to have the updated result
