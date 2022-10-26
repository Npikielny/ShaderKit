//
//  Operation.swift
//  
//
//  Created by Noah Pikielny on 7/6/22.
//

import Metal

public protocol PresentingOperation {
    func execute(commandQueue: MTLCommandQueue, library: MTLLibrary, drawable: MTLDrawable, renderDescriptor: MTLRenderPassDescriptor) async throws
}

extension PresentingOperation {
    public static func + <T: PresentingOperation>(lhs: Self, rhs: T) -> PresentingOperation {
        return RenderOperationSet(first: lhs, second: rhs)
    }
}

public protocol Operation: PresentingOperation {
    func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws
}

extension Operation {
    public func execute(commandQueue: MTLCommandQueue) async throws {
        guard let library = commandQueue.device.makeDefaultLibrary() else {
            throw ShaderError("Unable to make default library")
        }
        try await execute(commandQueue: commandQueue, library: library)
    }
}

extension Operation {
    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary, drawable: MTLDrawable, renderDescriptor: MTLRenderPassDescriptor) async throws {
        try await self.execute(commandQueue: commandQueue, library: library)
    }
}

public struct Execute: Operation {
    var execute: (MTLDevice, MTLLibrary) async throws -> Void
    
    public init(execute: @escaping (MTLDevice) async throws -> Void) {
        self.execute = { device, _ in try await execute(device) }
    }
    
    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws {
        try await execute(commandQueue.device, library)
    }
}

public struct FutureEncode: Operation {
    var encode: (MTLCommandBuffer, MTLLibrary) async throws -> Void
    
    public init(encode: @escaping (MTLCommandBuffer, MTLLibrary) async throws -> Void) {
        self.encode = encode
    }
    
    public init(futures: [Resource]) {
        self.encode = { commandBuffer, library in
            for future in futures {
                future.encode(commandBuffer: commandBuffer, library: library)
            }
        }
    }
    
    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        try await encode(commandBuffer, library)
        commandBuffer.commit()
    }
}
