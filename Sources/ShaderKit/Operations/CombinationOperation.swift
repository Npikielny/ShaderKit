//
//  CombinationOperation.swift
//  
//
//  Created by Noah Pikielny on 10/22/22.
//

import Metal

public struct OperationSet: PresentingOperation {
    var operations: [PresentingOperation]
    
    public init(first: PresentingOperation, second: PresentingOperation) {
        self.operations = [first, second]
    }
    
    public init(operations: [PresentingOperation]) {
        self.operations = operations
    }
    
    public func execute(commandQueue: MTLCommandQueue, drawable: MTLDrawable, renderDescriptor: MTLRenderPassDescriptor) async throws {
        for operation in operations {
            try await operation.execute(commandQueue: commandQueue, drawable: drawable, renderDescriptor: renderDescriptor)
        }
    }
}

@resultBuilder
public struct OperationSetBuilder {
    public static func buildBlock(_ components: PresentingOperation...) -> OperationSet {
        OperationSet(operations: components)
    }
    
    public static func buildArray(_ components: [PresentingOperation]) -> OperationSet {
        OperationSet(operations: components)
    }
}
