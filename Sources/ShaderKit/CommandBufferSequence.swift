//
//  CommandBufferSequence.swift
//  
//
//  Created by Noah Pikielny on 7/5/22.
//

import Metal

protocol Operation {
    func execute(commandQueue: MTLCommandQueue) async throws
}

struct Execute: Operation {
    var execute: (MTLDevice) async throws -> Void
    
    func execute(commandQueue: MTLCommandQueue) async throws { try await execute(commandQueue.device) }
}

public struct OperationSequence: Operation {
    var operations: [Operation]
    
    func execute(commandQueue: MTLCommandQueue) async throws {
        for operation in operations {
            try await operation.execute(commandQueue: commandQueue)
        }
    }
}

@resultBuilder
struct OperationSequenceBuilder {
    static func buildBlock(_ components: Operation...) -> Operation {
        OperationSequence(operations: components.map { [$0] }.reduce([], +))
    }
}
