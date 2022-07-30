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

public struct FutureEncode: Operation {
    var encode: (MTLCommandBuffer) async throws -> Void
    
    public init(encode: @escaping (MTLCommandBuffer) async throws -> Void) {
        self.encode = encode
    }
    
    public init(futures: [Resource]) {
        self.encode = { commandBuffer in 
            for future in futures {
                future.encode(commandBuffer: commandBuffer)
            }
        }
    }
    
    public func execute(commandQueue: MTLCommandQueue) async throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        try await encode(commandBuffer)
        commandBuffer.commit()
    }
}
