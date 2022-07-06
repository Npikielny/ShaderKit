//
//  CommandBufferSequence.swift
//  
//
//  Created by Noah Pikielny on 7/5/22.
//

import Metal

public protocol Operation {
    func execute(commandQueue: MTLCommandQueue) async throws
}

public struct Execute: Operation {
    var execute: (MTLDevice) async throws -> Void
    
    public init(execute: @escaping (MTLDevice) async throws -> Void) {
        self.execute = execute
    }
    
    public func execute(commandQueue: MTLCommandQueue) async throws { try await execute(commandQueue.device) }
}

public struct OperationSequence: Operation {
    var operations: [Operation]
    
    public init(operations: [Operation]) {
        self.operations = operations
    }
    
    public func execute(commandQueue: MTLCommandQueue) async throws {
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
