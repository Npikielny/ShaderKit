//
//  RenderPipeline.swift
//  
//
//  Created by Noah Pikielny on 7/21/22.
//

import MetalKit

enum EncodingFunction {
    case compute
    case vertex
    case fragment
}

public class RenderShader: SKShader {
    private var pipeline: RenderFunction
    public var vertexTextures: [Texture]
    public var fragmentTextures: [Texture]
    public var vertexBuffers: [Buffer]
    public var fragmentBuffers: [Buffer]
    
    private var renderPassDescriptor: RenderPassDescriptor
    private var workingDescriptor: MTLRenderPassDescriptor?
    
    private var vertexStart: Int
    private var vertexCount: Int
    
    public init(
        pipeline: RenderFunction,
        vertexTextures: [TextureConstructor] = [],
        fragmentTextures: [TextureConstructor] = [],
        vertexBuffers: [Buffer] = [],
        fragmentBuffers: [Buffer] = [],
        renderPassDescriptor: RenderPassDescriptorConstructor,
        vertexStart: Int = 0,
        vertexCount: Int = 6
    ) throws {
        self.pipeline = pipeline
        
        self.fragmentTextures = fragmentTextures.map { $0.construct() }
        self.vertexTextures = vertexTextures.map { $0.construct() }
        self.fragmentBuffers = fragmentBuffers
        self.vertexBuffers = vertexBuffers
        
        self.renderPassDescriptor = renderPassDescriptor.construct()
        
        if case let .custom(descriptor) = self.renderPassDescriptor {
            workingDescriptor = descriptor
        }
        
        self.vertexStart = vertexStart
        self.vertexCount = vertexCount
    }
    
    public convenience init(
        pipeline: RenderFunction,
        fragment: String,
        vertex: String,
        vertexTextures: [TextureConstructor] = [],
        fragmentTextures: [TextureConstructor] = [],
        vertexBuffers: [Buffer] = [],
        fragmentBuffers: [Buffer] = [],
        renderPassDescriptor: RenderPassDescriptorConstructor,
        vertexStart: Int = 0,
        vertexCount: Int = 6
    ) throws {
        try self.init(
            pipeline: pipeline,
            vertexTextures: vertexTextures,
            fragmentTextures: fragmentTextures,
            vertexBuffers: vertexBuffers,
            fragmentBuffers: fragmentBuffers,
            renderPassDescriptor: renderPassDescriptor,
            vertexStart: vertexStart,
            vertexCount: vertexCount
        )
    }
    
    public convenience init(
        inTexture: TextureConstructor,
        outTexture: TextureConstructor,
        fragment: String,
        vertex: String,
        vertexStart: Int = 0,
        vertexCount: Int = 6
    ) throws {
        let outTexture = outTexture.construct()
        
        try self.init(
            pipeline: RenderFunction(vertex: vertex, fragment: fragment, destination: outTexture),
            fragmentTextures: [inTexture],
            renderPassDescriptor: RenderPassDescriptor.future { device in
                let descriptor = MTLRenderPassDescriptor()
                descriptor.colorAttachments[0].texture = outTexture.unwrap(device: device)
                return descriptor
            },
            vertexStart: vertexStart,
            vertexCount: vertexCount
        )
    }
    
    func setRenderPassDescriptor(device: MTLDevice, descriptor: MTLRenderPassDescriptor) {
        switch renderPassDescriptor {
            case .drawable:
                self.workingDescriptor = descriptor
            case let .future(future):
                let descriptor = future(device)
                self.renderPassDescriptor = .custom(descriptor)
                self.workingDescriptor = descriptor
            case let .custom(renderPassDescriptor):
                self.workingDescriptor = renderPassDescriptor
        }
    }
    
    func attemptBypassDrawable(device: MTLDevice) {
        switch renderPassDescriptor {
            case .drawable:
                fatalError(
    """
    Working descriptor not set. This is due to using a `CommandBuffer` instead of a `RenderBuffer` or not initializing with a renderPassDescriptor.
    """
                )
            case .custom(let descriptor):
                workingDescriptor = descriptor
            case .future(let future):
                workingDescriptor = future(device)
        }
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        if workingDescriptor == nil {
            attemptBypassDrawable(device: commandBuffer.device)
        }
        guard let workingDescriptor else {
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
        let device = commandBuffer.device
        let (_, pipeline) = try! pipeline.unwrap(device: device, library: library)
        
        renderEncoder.setRenderPipelineState(pipeline)
        let wrapped = renderEncoder.wrapped
        
        wrapped.setTextures(device: device, textures: fragmentTextures, function: .fragment)
        wrapped.setTextures(device: device, textures: vertexTextures, function: .vertex)
        wrapped.setBuffers(commandBuffer: commandBuffer, library: library, buffers: &fragmentBuffers, function: .fragment)
        wrapped.setBuffers(commandBuffer: commandBuffer, library: library, buffers: &vertexBuffers, function: .vertex)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: vertexStart, vertexCount: vertexCount)
        renderEncoder.endEncoding()
    }
    
    public func copy(replacing newFragmentTextures: [Texture]? = nil) throws -> RenderShader {
        try RenderShader(
            pipeline: pipeline,
            vertexTextures: vertexTextures,
            fragmentTextures: fragmentTextures,
            vertexBuffers: vertexBuffers,
            fragmentBuffers: fragmentBuffers,
            renderPassDescriptor: renderPassDescriptor,
            vertexStart: vertexStart,
            vertexCount: vertexCount
        )
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
    case future((MTLDevice) -> MTLRenderPassDescriptor)
    
    public static func future(texture: Texture, loadAction: MTLLoadAction = .dontCare, storeAction: MTLStoreAction = .store) -> Self {
        .future { device in
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = texture.unwrap(device: device)
            descriptor.colorAttachments[0].loadAction = loadAction
            descriptor.colorAttachments[0].storeAction = storeAction
            return descriptor
        }
    }
    
    public func construct() -> RenderPassDescriptor { self }
}

extension MTLRenderPassDescriptor: RenderPassDescriptorConstructor {
    public func construct() -> RenderPassDescriptor { .custom(self) }
}

public protocol RenderPassDescriptorConstructor {
    func construct() -> RenderPassDescriptor
}
