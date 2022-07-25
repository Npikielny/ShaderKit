//
//  RenderPipeline.swift
//  
//
//  Created by Noah Pikielny on 7/21/22.
//

import MetalKit

enum RenderFunction {
    case vertex
    case fragment
}

public class RenderPipeline: SKShader {
    private var pipeline: Pipeline
    public var vertexTextures: [Texture]
    public var fragmentTextures: [Texture]
    public var vertexBuffers: [Buffer<MTLRenderCommandEncoder>]
    public var fragmentBuffers: [Buffer<MTLRenderCommandEncoder>]
    
    public let device: MTLDevice
    
    let renderPassDescriptor: RenderPassDescriptor
    private var workingDescriptor: MTLRenderPassDescriptor?
    
    public init(
        device: MTLDevice,
        pipeline: Pipeline,
        vertexTextures: [TextureConstructor] = [],
        fragmentTextures: [TextureConstructor] = [],
        vertexBuffers: [Buffer<MTLRenderCommandEncoder>] = [],
        fragmentBuffers: [Buffer<MTLRenderCommandEncoder>] = [],
        renderPassDescriptor: RenderPassDescriptorConstructor
    ) throws {
        self.device = device
        
        self.pipeline = pipeline
        
        self.fragmentTextures = fragmentTextures.map { $0.construct() }
        self.vertexTextures = vertexTextures.map { $0.construct() }
        self.fragmentBuffers = fragmentBuffers
        self.vertexBuffers = vertexBuffers
        
        self.renderPassDescriptor = renderPassDescriptor.construct()
        
        if case let .custom(descriptor) = self.renderPassDescriptor {
            workingDescriptor = descriptor
        }
    }
    
    public convenience init(
        device: MTLDevice,
        pipelineConstructor: RenderPipelineDescriptorConstructor,
        fragment: String,
        vertex: String,
        vertexTextures: [TextureConstructor] = [],
        fragmentTextures: [TextureConstructor] = [],
        vertexBuffers: [Buffer<MTLRenderCommandEncoder>] = [],
        fragmentBuffers: [Buffer<MTLRenderCommandEncoder>] = [],
        renderPassDescriptor: RenderPassDescriptorConstructor
    ) throws {
        try self.init(
            device: device,
            pipeline: .constructors(fragment, vertex, pipelineConstructor),
            vertexTextures: vertexTextures,
            fragmentTextures: fragmentTextures,
            vertexBuffers: vertexBuffers,
            fragmentBuffers: fragmentBuffers,
            renderPassDescriptor: renderPassDescriptor
        )
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
        guard let workingDescriptor = workingDescriptor else {
            fatalError(
"""
Working descriptor not set. This is due to using a `CommandBuffer` instead of a `RenderBuffer` or not initializing with a renderPassDescriptor.
"""
            )
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: workingDescriptor) else {
            fatalError(
"""
Unabled to make render encoder \(pipeline.description)
"""
            )
        }
        let pipeline = try! pipeline.unwrap(device: device)
        
        renderEncoder.setRenderPipelineState(pipeline)
        fragmentTextures.encode(device: device, encoder: renderEncoder, function: .fragment)
        vertexTextures.encode(device: device, encoder: renderEncoder, function: .vertex)
        fragmentBuffers.encode(device: device, encoder: renderEncoder, renderFunction: .fragment)
        vertexBuffers.encode(device: device, encoder: renderEncoder, renderFunction: .vertex)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
    }
    
    public enum Pipeline {
        case state(_ state: MTLRenderPipelineState, _ description: String)
        case functions(_ vertex: MTLFunction, _ fragment: MTLFunction, _ description: String, _ format: RenderPipelineDescriptorConstructor)
        case constructors(_ vertex: String, _ fragment: String, _ format: RenderPipelineDescriptorConstructor)
        
        var description: String {
            switch self {
                case let .state(_, description): return description
                case let .functions(_, _, description, _): return description
                case let .constructors(vertex, fragment, _): return "(\(vertex), \(fragment))"
            }
        }
        
        static func makePipeline(
            vertex: String,
            fragment: String,
            format: RenderPipelineDescriptorConstructor,
            device: MTLDevice
        ) throws -> MTLRenderPipelineState {
            guard let library = device.makeDefaultLibrary() else { fatalError("Device \(device) unable to make compile shaders") }
            guard let vertex = library.makeFunction(name: vertex) else { fatalError("Unable to make function \(vertex)") }
            guard let fragment = library.makeFunction(name: fragment) else { fatalError("Unable to make function \(fragment)") }
            
            
            return try makePipeline(vertex: vertex, fragment: fragment, format: format, device: device)
        }
        
        static func makePipeline(
            vertex: MTLFunction,
            fragment: MTLFunction,
            format: RenderPipelineDescriptorConstructor,
            device: MTLDevice
        ) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            
            switch format.construct() {
                case let .pixelFormat(format):
                    descriptor.colorAttachments[0].pixelFormat = format
                case let .texture(texture):
                    descriptor.colorAttachments[0].pixelFormat = texture.unwrap(device: device).pixelFormat
            }
            
            
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        
        mutating func unwrap(device: MTLDevice) throws -> MTLRenderPipelineState {
            switch self {
                case let .state(state, _):
                    return state
                case let .functions(vertex, fragment, description, format):
                    let pipeline = try Self.makePipeline(
                        vertex: vertex,
                        fragment: fragment,
                        format: format,
                        device: device
                    )
                    self = .state(pipeline, description)
                    return pipeline
                case let .constructors(vertex, fragment, format):
                    let pipeline = try Self.makePipeline(
                        vertex: vertex,
                        fragment: fragment,
                        format: format,
                        device: device
                    )
                    self = .state(pipeline, "(\(vertex), \(fragment))")
                    return pipeline
            }
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