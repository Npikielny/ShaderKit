//
//  Pipeline.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public struct StaticComputeShader: SKConstructor {
    public init(name: String, textures: [TextureConstructor] = [TextureConstructor](), buffers: [Buffer<MTLComputeCommandEncoder>] = [Buffer<MTLComputeCommandEncoder>](), threadGroupSize: MTLSize, threadGroups: MTLSize) {
        self.name = name
        self.textures = textures
        self.buffers = buffers
        self.threadGroupSize = threadGroupSize
        self.threadGroups = threadGroups
    }
    
    public let name: String
    public var textures = [TextureConstructor]()
    public var buffers = [Buffer<MTLComputeCommandEncoder>]()
    
    public let threadGroupSize: MTLSize
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
    public let pipeline: MTLComputePipelineState
    public var textures: [Texture]
    public var buffers: [Buffer<MTLComputeCommandEncoder>]
    public let device: MTLDevice
    
    public let threadGroupSize: MTLSize
    public var threadGroups: MTLSize
    
    public init(
        device: MTLDevice,
        name: String,
        textures: [TextureConstructor],
        buffers: [Buffer<MTLComputeCommandEncoder>],
        threadGroupSize: MTLSize,
        threadGroups: MTLSize
    ) throws {
        let library = device.makeDefaultLibrary()
        guard let function = library?.makeFunction(name: name) else {
            throw ShaderError("Failed making kernel \(name)")
        }
        
        self.textures = textures.map { $0.construct() }
        self.buffers = buffers
        self.pipeline = try device.makeComputePipelineState(function: function)
        self.device = device
        
        self.threadGroups = threadGroups
        self.threadGroupSize = threadGroupSize
    }
    
    public func encode(commandBuffer: MTLCommandBuffer) {
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else { fatalError("Unable to make command encoder") }
        commandEncoder.setComputePipelineState(pipeline)
        textures.encode(device: device, encoder: commandEncoder)
        buffers.encode(device: device, encoder: commandEncoder)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
    }
}

enum RenderFunction {
    case vertex
    case fragment
}

public class RenderPipeline: SKShader {
    public let pipelineConstructor: (RenderPipelineDescriptor, fragment: MTLFunction, vertex: MTLFunction)
    private var pipeline: MTLRenderPipelineState? = nil
    public var vertexTextures: [Texture]
    public var fragmentTextures: [Texture]
    public var vertexBuffers: [Buffer<MTLRenderCommandEncoder>]
    public var fragmentBuffers: [Buffer<MTLRenderCommandEncoder>]
    
    public let device: MTLDevice
    
    let renderPassDescriptor: RenderPassDescriptor
    private var workingDescriptor: MTLRenderPassDescriptor?
    
    public init(
        device: MTLDevice,
        pipelineConstructor: RenderPipelineDescriptorConstructor,
        fragment: String,
        vertex: String,
        vertexTextures: [TextureConstructor],
        fragmentTextures: [TextureConstructor],
        vertexBuffers: [Buffer<MTLRenderCommandEncoder>],
        fragmentBuffers: [Buffer<MTLRenderCommandEncoder>],
        renderPassDescriptor: RenderPassDescriptorConstructor
    ) throws {
        self.device = device
        
        let library = device.makeDefaultLibrary()
        guard let fragmentFunction = library?.makeFunction(name: fragment),
              let vertexFunction = library?.makeFunction(name: vertex) else {
            throw ShaderError("Unabled to create function \(fragment) or \(vertex) with device \(device.name)")
        }
        
        self.pipelineConstructor = (pipelineConstructor.construct(), fragmentFunction, vertexFunction)
        
        self.fragmentTextures = fragmentTextures.map { $0.construct() }
        self.vertexTextures = vertexTextures.map { $0.construct() }
        self.fragmentBuffers = fragmentBuffers
        self.vertexBuffers = vertexBuffers
        
        self.renderPassDescriptor = renderPassDescriptor.construct()
        
        if case let .custom(descriptor) = self.renderPassDescriptor {
            workingDescriptor = descriptor
        }
    }
    
    func createPipeline() {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.fragmentFunction = pipelineConstructor.fragment
        descriptor.vertexFunction = pipelineConstructor.vertex
        
        descriptor.colorAttachments[0].pixelFormat = {
            switch pipelineConstructor.0 {
                case let .pixelFormat(format):
                    return format
                case let .texture(.raw(texture)):
                    return texture.pixelFormat
                case let .texture(.loadable(loadable)):
                    return loadable.texture(device: device).pixelFormat
            }
        }()
        
        self.pipeline = try! device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    func setRenderPassDescriptor(descriptor: MTLRenderPassDescriptor) {
        switch renderPassDescriptor {
            case .drawable:
                self.workingDescriptor = descriptor
            case .custom(let renderPassDescriptor):
                self.workingDescriptor = renderPassDescriptor
        }
    }
    
    public func encode(commandBuffer: MTLCommandBuffer) {
        if let pipeline = pipeline {
            guard let workingDescriptor = workingDescriptor else {
                fatalError(
"""
Working descriptor not set. This is due to using a `CommandBuffer` instead of a `RenderCommandBuffer` or not initializing with a renderPassDescriptor.
"""
                )
            }

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: workingDescriptor) else {
                fatalError(
"""
Unabled to make render encoder \(pipelineConstructor.fragment.name), \(pipelineConstructor.vertex.name)
"""
                )
            }
            renderEncoder.setRenderPipelineState(pipeline)
            fragmentTextures.encode(device: device, encoder: renderEncoder, function: .fragment)
            vertexTextures.encode(device: device, encoder: renderEncoder, function: .vertex)
            fragmentBuffers.encode(device: device, encoder: renderEncoder, renderFunction: .fragment)
            vertexBuffers.encode(device: device, encoder: renderEncoder, renderFunction: .vertex)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        } else {
            createPipeline()
            encode(commandBuffer: commandBuffer)
        }
    }
    
    
}

// MARK: Pipeline Descriptor
public enum RenderPipelineDescriptor: RenderPipelineDescriptorConstructor {
    case pixelFormat(MTLPixelFormat)
    case texture(Texture)
    
    public func construct() -> RenderPipelineDescriptor { self }
}

/**Used to create a `RenderPipelineDescriptor`
 
 The following types conform to `RenderPipelineDescriptorConstructor`:
 1. `RenderPipelineDescriptor`
 2. `MTLPixelFormat`
 3. `Texture`
 */
public protocol RenderPipelineDescriptorConstructor {
    func construct() -> RenderPipelineDescriptor
}

extension MTLPixelFormat: RenderPipelineDescriptorConstructor {
    public func construct() -> RenderPipelineDescriptor { .pixelFormat(self) }
}

extension Texture: RenderPipelineDescriptorConstructor {
    public func construct() -> RenderPipelineDescriptor { .texture(self) }
}

// MARK: Render Pass Descriptor
public enum RenderPassDescriptor: RenderPassDescriptorConstructor {
    case drawable
    case custom(MTLRenderPassDescriptor)
    
    public func construct() -> RenderPassDescriptor { self }
}

extension MTLRenderPassDescriptor: RenderPassDescriptorConstructor {
    public func construct() -> RenderPassDescriptor { .custom(self) }
}

public protocol RenderPassDescriptorConstructor {
    func construct() -> RenderPassDescriptor
}

// MARK: MTLRenderCommandEncoder Helpers
extension MTLRenderCommandEncoder {
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int, function: RenderFunction) {
        switch function {
            case .vertex:
                setVertexBuffer(buffer, offset: offset, index: index)
            case .fragment:
                setFragmentBuffer(buffer, offset: offset, index: index)
        }
    }
    
    func setTexture(_ texture: MTLTexture, index: Int, function: RenderFunction) {
        switch function {
            case .vertex:
                setVertexTexture(texture, index: index)
            case .fragment:
                setFragmentTexture(texture, index: index)
        }
    }
}
