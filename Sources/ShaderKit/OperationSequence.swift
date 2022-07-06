//
//  OperationSequence.swift
//  
//
//  Created by Noah Pikielny on 7/5/22.
//

import Metal

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

// MARK: - Render Operation
public struct RenderOperationSequence: RenderOperation {
    var operations: [RenderOperation]
    
    public init(operations: [RenderOperation]) {
        self.operations = operations
    }
    
    public func execute(
        commandQueue: MTLCommandQueue,
        drawable: MTLDrawable,
        renderDescriptor: MTLRenderPassDescriptor
    ) async throws {
        for operation in operations {
            try await operation.execute(commandQueue: commandQueue, drawable: drawable, renderDescriptor: renderDescriptor)
        }
    }
}

@resultBuilder
struct RenderOperationSequenceBuilder {
    static func buildBlock(_ components: RenderOperation...) -> RenderOperation {
        RenderOperationSequence(operations: components.map { [$0] }.reduce([], +))
    }
}

