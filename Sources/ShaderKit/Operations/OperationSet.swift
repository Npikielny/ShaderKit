//
//  OperationSet.swift
//  
//
//  Created by Noah Pikielny on 10/22/22.
//

import Metal

public struct RenderOperationSet: PresentingOperation {
    var operations: [PresentingOperation]
    
    public init(first: PresentingOperation, second: PresentingOperation) {
        self.operations = [first, second]
    }
    
    public init(@RenderOperationSetBuilder operations: () -> [PresentingOperation]) {
        self.operations = operations()
    }
    
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
public struct RenderOperationSetBuilder {
    public static func buildBlock(_ components: PresentingOperation...) -> [PresentingOperation] {
        components
    }
    
    public static func buildArray(_ components: [PresentingOperation]) -> [PresentingOperation] {
        components
    }
}

public struct CommandOperationSet: PresentingOperation {
    var operations: [Operation]
    
    public init(first: Operation, second: Operation) {
        self.operations = [first, second]
    }
    
    public init(@CommandOperationSetBuilder operations: () -> [Operation]) {
        self.operations = operations()
    }
    
    public init(operations: [Operation]) {
        self.operations = operations
    }
    
    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary, drawable: MTLDrawable, renderDescriptor: MTLRenderPassDescriptor) async throws {
        for operation in operations {
            try await operation.execute(commandQueue: commandQueue)
        }
    }
}

@resultBuilder
public struct CommandOperationSetBuilder {
    public static func buildBlock(_ components: Operation...) -> [Operation] {
        components
    }
    
    public static func buildArray(_ components: [Operation]) -> [Operation] {
        components
    }
}
