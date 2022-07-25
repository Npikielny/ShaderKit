//
//  ComputeHelpers.swift
//  
//
//  Created by Noah Pikielny on 7/7/22.
//

import Metal

public struct ComputePass: SKShader {
    public var pipelines: [ComputePipeline]
    public var size: (MTLDevice) -> SIMD2<Int>
    
    public init(texture: Texture, pipelines: [ComputePipeline]) {
        size = { device in
            let texture = texture.unwrap(device: device)
            return SIMD2(texture.width, texture.height)
        }
        self.pipelines = pipelines
    }
    
    public init(buffer: Buffer<MTLComputeCommandEncoder>, width: Int, pipelines: [ComputePipeline]) {
        size = { device in
            SIMD2(
                min(width, buffer.count),
                max((buffer.count + width - 1) / width, 1)
            )
        }
        self.pipelines = pipelines
    }
    
    public init(size: SIMD2<Int>, pipelines: [ComputePipeline]) {
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
                depth: 1
            )
            pipelines[i].encode(commandBuffer: commandBuffer)
        }
    }
}
