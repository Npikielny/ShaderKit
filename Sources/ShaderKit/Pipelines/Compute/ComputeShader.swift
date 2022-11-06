//
//  ComputePipeline.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public class ComputeShader: SKShader {
    public var pipeline: ComputeFunction
    public var textures: [Texture]
    public var buffers: [Buffer]
    
    public let threadGroupSize: MTLSize
    public var threadGroups: MTLSize?
    
    public init(
        pipeline: ComputeFunction,
        textures: [TextureConstructor] = [],
        buffers: [Buffer] = [],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize? = nil
    ) throws {
        self.textures = textures.map { $0.construct() }
        self.buffers = buffers
        self.pipeline = pipeline
        
        self.threadGroups = threadGroups
        self.threadGroupSize = threadGroupSize
    }
    
    public convenience init(
        name: String,
        constants: MTLFunctionConstantValues? = nil,
        textures: [TextureConstructor] = [],
        buffers: [Buffer] = [],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize? = nil
    ) throws {
        try self.init(
            pipeline: ComputeFunction(name: name, constants: constants),
            textures: textures,
            buffers: buffers,
            threadGroupSize: threadGroupSize,
            threadGroups: threadGroups
        )
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        let device = commandBuffer.device
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError("Unable to make command encoder") }
        guard let threadGroups = threadGroups else {
            fatalError("threadGroups must be set before encode time")
        }

        let (_, pipeline) = try! pipeline.unwrap(device: device, library: library)
        commandEncoder.setComputePipelineState(pipeline)
        let wrapped = commandEncoder.wrapped
        wrapped.setTextures(device: device, textures: textures, function: .compute)
        wrapped.setBuffers(commandBuffer: commandBuffer, library: library, buffers: &buffers, function: .compute)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
    }
    
    func copy() throws -> ComputeShader {
        try ComputeShader(
            pipeline: pipeline,
            textures: textures,
            buffers: buffers,
            threadGroupSize: threadGroupSize,
            threadGroups: threadGroups
        )
    }
}

extension ComputeShader {
    public enum Pipeline {
        case state(_ state: MTLComputePipelineState)
        case function(_ function: MTLFunction)
        case constructor(_ name: String, _ constants: MTLFunctionConstantValues?)
        
        static func makePipeline(
            _ name: String,
            constants: MTLFunctionConstantValues? = nil,
            device: MTLDevice
        ) throws -> MTLComputePipelineState {
            guard let library = device.makeDefaultLibrary() else { fatalError("Device \(device) unable to make compile shaders") }
            
            if let constants = constants {
                let function = try library.makeFunction(name: name, constantValues: constants)
                return try makePipeline(function, device: device)
            }
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
                case .constructor(let name, let constants):
                    let pipeline = try Self.makePipeline(name, constants: constants, device: device)
                    self = .state(pipeline)
                    return pipeline
            }
        }
    }
    
    public enum Dispatch {
        case size(MTLSize)
        case texture(Texture)
        case buffer(buffer: Buffer, _ maxWidth: Int? = nil)
        case future((MTLDevice) -> MTLSize)
        
        func getSize(device: MTLDevice) -> MTLSize {
            switch self {
                case let .size(size): return size
                case let .texture(texture):
                    let unwrapped = texture.unwrap(device: device)
                    return MTLSize(width: unwrapped.width, height: unwrapped.height, depth: 1)
                case let .buffer(buffer: buffer, maxWidth):
                    if let maxWidth {
                        return MTLSize(width: min(buffer.count, maxWidth), height: (buffer.count + maxWidth - 1) / maxWidth, depth: 1)
                    }
                    return MTLSize(width: buffer.count, height: 1, depth: 1)
                case let .future(future):
                    return future(device)
            }
        }
    }
}
