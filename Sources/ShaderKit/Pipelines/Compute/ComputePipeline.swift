//
//  ComputePipeline.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public class ComputePipeline: SKShader {
    public var pipeline: Pipeline
    public var textures: [Texture]
    public var buffers: [Buffer<MTLComputeCommandEncoder>]
    
    public let threadGroupSize: MTLSize
    public var threadGroups: MTLSize?
    
    public init(
        pipeline: Pipeline,
        textures: [TextureConstructor] = [],
        buffers: [ComputeBufferConstructor] = [],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize? = nil
    ) throws {
        self.textures = textures.map { $0.construct() }
        self.buffers = buffers.map { $0.construct() }
        self.pipeline = pipeline
        
        self.threadGroups = threadGroups
        self.threadGroupSize = threadGroupSize
    }
    
    public convenience init(
        name: String,
        textures: [TextureConstructor] = [],
        buffers: [ComputeBufferConstructor] = [],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize? = nil
    ) throws {
        try self.init(
            pipeline: .constructor(name),
            textures: textures,
            buffers: buffers,
            threadGroupSize: threadGroupSize,
            threadGroups: threadGroups
        )
    }
    
    public convenience init(
        function: MTLFunction,
        textures: [TextureConstructor] = [],
        buffers: [ComputeBufferConstructor] = [],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize? = nil
    ) throws {
        try self.init(
            pipeline: .function(function),
            textures: textures,
            buffers: buffers,
            threadGroupSize: threadGroupSize,
            threadGroups: threadGroups
        )
    }
    
    public func encode(commandBuffer: MTLCommandBuffer) {
        let device = commandBuffer.device
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError("Unable to make command encoder") }
        guard let threadGroups = threadGroups else {
            fatalError("threadGroups must be set before encode time")
        }

        let pipeline = try! pipeline.unwrap(device: device)
        commandEncoder.setComputePipelineState(pipeline)
        textures.encode(device: device, encoder: commandEncoder)
        buffers.encode(commandBuffer: commandBuffer, encoder: commandEncoder)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
    }
    
    public enum Pipeline {
        case state(_ state: MTLComputePipelineState)
        case function(_ function: MTLFunction)
        case constructor(_ name: String)
        
        static func makePipeline(_ name: String, device: MTLDevice) throws -> MTLComputePipelineState {
            guard let library = device.makeDefaultLibrary() else { fatalError("Device \(device) unable to make compile shaders") }
            guard let function = library.makeFunction(name: name) else { fatalError("Unable to make function \(name)") }
            return try makePipeline(function, device: device)
        }
        
        static func makePipeline(_ function: MTLFunction, device: MTLDevice) throws -> MTLComputePipelineState {
            try device.makeComputePipelineState(function: function)
        }
        
        mutating func unwrap(device: MTLDevice) throws -> MTLComputePipelineState {
            switch self {
                case .state(let state):
                    return state
                case .function(let function):
                    let pipeline = try Self.makePipeline(function, device: device)
                    self = .state(pipeline)
                    return pipeline
                case .constructor(let name):
                    let pipeline = try Self.makePipeline(name, device: device)
                    self = .state(pipeline)
                    return pipeline
            }
        }
    }
}
