//
//  Pipeline.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public struct StaticComputeShader: SKConstructor {
    public var name: String
    public var textures = [TextureConstructor]()
    public var buffers = [Buffer<MTLComputeCommandEncoder>]()
    
    public var threadGroupSize: MTLSize
    public var threadGroups: MTLSize
    
    public func initialize(device: MTLDevice) throws -> ComputePipeline {
        try ComputePipeline(
            device: device,
            name: name,
            textures: textures,
            buffers: buffers,
            threadGroupSize: threadGroupSize,
            threadGroups: threadGroups
        )
    }
    
    public func initialize(device: MTLDevice) throws -> SKShader {
        let s: ComputePipeline = try initialize(device: device)
        return s
    }
}

public class ComputePipeline: SKShader {
    public var pipeline: MTLComputePipelineState
    public var textures: [Texture]
    public var buffers: [Buffer<MTLComputeCommandEncoder>]
    public var device: MTLDevice!
    
    public var threadGroupSize: MTLSize
    public var threadGroups: MTLSize
    
    public init(
        device: MTLDevice,
        name: String,
        textures: [TextureConstructor], buffers: [Buffer<MTLComputeCommandEncoder>],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize
    ) throws {
        let library = device.makeDefaultLibrary()
        guard let function = library?.makeFunction(name: name) else {
            throw ShaderError("Failed making kernel \(name)")
        }
        
        self.textures = textures.map { $0.convert() }
        self.buffers = buffers
        self.pipeline = try device.makeComputePipelineState(function: function)
        self.device = device
        
        self.threadGroups = threadGroups
        self.threadGroupSize = threadGroupSize
    }
    
    public func encode(commandBuffer: MTLCommandBuffer) {
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        textures.encode(device: device, encoder: commandEncoder)
        buffers.encode(device: device, encoder: commandEncoder)
        commandEncoder.dispatchThreads(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
}
