//
//  ComputeHelpers.swift
//  
//
//  Created by Noah Pikielny on 7/7/22.
//

import Metal

public struct ComputePass: SKShader {
    public var pipelines: [ComputePipeline]
    public var size: (MTLDevice) -> SIMD3<Int>
    
    public init(texture: Texture, pipelines: [ComputePipeline]) {
        size = { device in
            let texture = texture.unwrap(device: device)
            return SIMD3(texture.width, texture.height, texture.depth)
        }
        self.pipelines = pipelines
    }
    
    /// For 2D dispatches
    public init(buffer: Buffer<MTLComputeCommandEncoder>, width: Int, pipelines: [ComputePipeline]) {
        size = { device in
            SIMD3(
                min(width, buffer.count),
                max((buffer.count + width - 1) / width, 1),
                1
            )
        }
        self.pipelines = pipelines
    }
    
    public init(size: SIMD2<Int>, pipelines: [ComputePipeline]) {
        self.size = { _ in SIMD3(size.x, size.y, 1) }
        self.pipelines = pipelines
    }
    
    public init(size: SIMD3<Int>, pipelines: [ComputePipeline]) {
        self.size = { _ in size }
        self.pipelines = pipelines
    }
}

extension ComputePass {
    public func encode(commandBuffer: MTLCommandBuffer) {
        let size = size(commandBuffer.device)
        for i in 0..<pipelines.count {
            let groupSize = pipelines[i].threadGroupSize
            pipelines[i].threadGroups = MTLSize(
                width: (size.x + groupSize.width - 1) / groupSize.width,
                height: (size.y + groupSize.height - 1) / groupSize.height,
                depth: (size.z + groupSize.depth - 1) / groupSize.depth
            )
            pipelines[i].encode(commandBuffer: commandBuffer)
        }
    }
}

extension ComputePass: Operation {
    public func execute(commandQueue: MTLCommandQueue) async throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ShaderError("Unabled to make command buffer with \(commandQueue.device.name)")
        }
        encode(commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
