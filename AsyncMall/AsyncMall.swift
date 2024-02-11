//
//  AsyncMall.swift
//  AsyncMall
//
//  Created by Alex Culeva on 26.02.2024.
//

import Foundation
import AsyncAlgorithms

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

enum InType {
    case trigger
    case reads
    case zip
}

struct InputNode<V> {
    var inType: InType
    var node: MallNode<V>
}

postfix operator >!
postfix func >! <Value: Sendable>(left: MallNode<Value>) -> InputNode<Value> {
    InputNode(inType: .trigger, node: left)
}

postfix operator >?
postfix func >? <Value: Sendable>(left: MallNode<Value>) -> InputNode<Value> {
    InputNode(inType: .reads, node: left)
}

postfix operator >%
postfix func >% <Value: Sendable>(left: MallNode<Value>) -> InputNode<Value> {
    InputNode(inType: .zip, node: left)
}

prefix operator ~>
prefix func ~><Value: Sendable>(right: MallNode<Value>) -> MallNode<Value> {
    right
}

// parameter packs

@resultBuilder
enum CancellablesBuilder {
    static func buildBlock(_ components: VoidTask...) -> Set<VoidTask> {
        Set(components)
    }
}

typealias VoidTask = Task<Void, Never>

@resultBuilder
enum OpBuilder {
    static func buildBlock<I1, O1>(
        _ input1: InputNode<I1>,
        _ op: @Sendable @escaping (I1) -> O1,
        _ output1: MallNode<O1>
    ) -> VoidTask {
        Task {
            switch (input1.inType) {
            case (.trigger):
                for await output in await input1.node.subscribe().dropFirst() {
                    let result = op(output)
                    await output1.send(result)
                    print("trigger sent")
                }
            case (.zip), (.reads):
                fatalError()
            }
        }
    }

    static func buildBlock<I1, I2, O1>(
        _ input1: InputNode<I1>,
        _ input2: InputNode<I2>,
        _ op: @Sendable @escaping (I1, I2) -> O1,
        _ output1: MallNode<O1>
    ) -> VoidTask {
        Task {
            switch (input1.inType, input2.inType) {
            case (.trigger, .trigger):
                for await output in await combineLatest(
                    input1.node.subscribe().dropFirst(),
                    input2.node.subscribe().dropFirst()
                ).dropFirst().map(op) {
                    await output1.send(output)
                }
            case (.trigger, .reads):
                for await n1 in await input1.node.subscribe().dropFirst() {
                    await output1.send(op(n1, await input2.node.value))
                }
            case (.reads, .trigger):
                for await n2 in await input2.node.subscribe().dropFirst() {
                    await output1.send(op(await input1.node.value, n2))
                }
            case (.zip, .zip):
                for await output in await zip(
                    input1.node.subscribe().dropFirst(),
                    input2.node.subscribe().dropFirst()
                ).map(op) {
                    await output1.send(output)
                }
            default:
                fatalError()
            }
        }
    }
}

func op(@OpBuilder _ op: () -> VoidTask) -> VoidTask {
    op()
}
