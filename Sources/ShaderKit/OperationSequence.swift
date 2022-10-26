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
    
    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws {
        for operation in operations {
            try await operation.execute(commandQueue: commandQueue, library: library)
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
public struct RenderOperationSequence: PresentingOperation {
    var operations: [PresentingOperation]
    
    public init(operations: [PresentingOperation]) {
        self.operations = operations
    }
    
    public func execute(
        commandQueue: MTLCommandQueue,
        library: MTLLibrary,
        drawable: MTLDrawable,
        renderDescriptor: MTLRenderPassDescriptor
    ) async throws {
        for operation in operations {
            try await operation.execute(commandQueue: commandQueue, library: library, drawable: drawable, renderDescriptor: renderDescriptor)
        }
    }
}

@resultBuilder
struct RenderOperationSequenceBuilder {
    static func buildBlock(_ components: PresentingOperation...) -> PresentingOperation {
        RenderOperationSequence(operations: components.map { [$0] }.reduce([], +))
    }
}

