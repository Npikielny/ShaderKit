//
//  Operation.swift
//  
//
//  Created by Noah Pikielny on 7/6/22.
//

import Metal

public protocol RenderOperation {
    func execute(commandQueue: MTLCommandQueue, drawable: MTLDrawable, renderDescriptor: MTLRenderPassDescriptor) async throws
}

public protocol Operation: RenderOperation {
    func execute(commandQueue: MTLCommandQueue) async throws
}

extension Operation {
    public func execute(
        commandQueue: MTLCommandQueue,
        drawable: MTLDrawable,
        renderDescriptor: MTLRenderPassDescriptor
    ) async throws {
        try await self.execute(commandQueue: commandQueue)
    }
}

public struct Execute: Operation {
    var execute: (MTLDevice) async throws -> Void
    
    public init(execute: @escaping (MTLDevice) async throws -> Void) {
        self.execute = execute
    }
    
    public func execute(commandQueue: MTLCommandQueue) async throws { try await execute(commandQueue.device) }
}
