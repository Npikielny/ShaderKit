//
//  File.swift
//  
//
//  Created by Noah Pikielny on 7/7/22.
//

import Metal

public protocol ComputePass: SKShader {
    var pipelines: [ComputePipeline] { get }
    var size: (MTLDevice) -> SIMD2<Int> { get }
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

public protocol TexturePass: ComputePass {
    var dispatchTexture: Texture { get }
}

extension TexturePass {
    public var size: (MTLDevice) -> SIMD2<Int> {
        { device in
            let texture = dispatchTexture.unwrap(device: device)
            return SIMD2(texture.width, texture.height)
        }
    }
}
