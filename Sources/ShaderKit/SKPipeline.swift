//
//  SKPipeline.swift
//  
//
//  Created by Noah Pikielny on 6/11/22.
//

import Metal

public struct ComputeFunction: SKFunction {
    var textures: [(texture: MTLTexture, index: Int)] = []
    var buffers: [(buffer: MTLBuffer, offset: Int, index: Int)] = []
    var constants: [(MTLCommandEncoder?) -> Void] = []
    /**Handles resources that change on a frame by frame basis**/
    var runtimeResources: (MTLCommandEncoder?) -> Void = { _ in }
    var pipeline: MTLComputePipelineState? = nil
    
    public var completion: (Self) -> Void = { _ in }
    /**The name of the kernel function to compile**/
    var name: String
    
    public mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws {
        guard let function = library?.makeFunction(name: name) else {
            throw SKError(description: "Unable to make function named \(name)")
        }
        guard let kernel = try device?.makeComputePipelineState(function: function) else {
            throw SKError(description: "Unabled to make kernel from function named \(name)")
        }
        
        pipeline = kernel
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let pipeline = pipeline else {
            fatalError("Compute pipeline \(name) not initialized. This could be because its parent's initializer was never called.")
        }

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.setComputePipelineState(pipeline)
        for (buffer, offset, index) in buffers {
            encoder?.setBuffer(buffer, offset: offset, index: index)
        }
        for (texture, index) in textures {
            encoder?.setTexture(texture, index: index)
        }
        for constant in constants {
            constant(encoder)
        }
        runtimeResources(encoder)
        // TODO: Dispatch
        encoder?.endEncoding()
        completion(self)
    }
}

internal struct RenderFunctionComponent: SKFunction {
    var textures: [(texture: MTLTexture, index: Int)] = []
    var buffers: [(buffer: MTLBuffer, offset: Int, index: Int)] = []
    var constants: [(MTLRenderCommandEncoder?) -> Void] = []
    var runtimeResources: (MTLRenderCommandEncoder?) -> Void = { _ in }
    
    var component: Component
    
    public var completion: (Self) -> Void = { _ in }
    
    mutating func initialize(device: MTLDevice?, library: MTLLibrary?) {
        
    }
    
    public func encode(encoder: MTLRenderCommandEncoder?) {
        for (buffer, offset, index) in buffers {
            encoder?.setBuffer(buffer, offset: offset, index: index, component: component)
        }
        for (texture, index) in textures {
            encoder?.setTexture(texture, index: index, component: component)
        }
        for constant in constants {
            constant(encoder)
        }
        runtimeResources(encoder)
        completion(self)
    }
}

extension RenderFunctionComponent {
    enum Component {
        case vertex
        case fragment
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {}
}

extension MTLRenderCommandEncoder {
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int, component: RenderFunctionComponent.Component) {
        component == .vertex ?
        setVertexBuffer(buffer, offset: offset, index: index) :
        setFragmentBuffer(buffer, offset: offset, index: index)
    }
    
    func setTexture(_ texture: MTLTexture, index: Int, component: RenderFunctionComponent.Component) {
        component == .vertex ?
        setVertexTexture(texture, index: index) :
        setFragmentTexture(texture, index: index)
    }
    
    func setBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int, component: RenderFunctionComponent.Component) {
        component == .vertex ?
        setVertexBytes(bytes, length: length, index: index) :
        setFragmentBytes(bytes, length: length, index: index)
    }
}

public struct RenderFunction: SKUnit {
    
    var vertexFunction = RenderFunctionComponent(component: .vertex)
    var fragmentFunction = RenderFunctionComponent(component: .fragment)
    
    var renderPipeline: MTLRenderPipelineState? = nil
    
    var renderPassDescriptor: RenderPassDescriptor = .default
    var completion: (_ function: Self) -> Void = { _ in }
    
    /**The name of the vertex function to compile*/
    var vertexName: String
    /**The name of the fragment function to compile*/
    var fragmentName: String
    
    public mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws {
        vertexFunction.initialize(device: device, library: library)
        fragmentFunction.initialize(device: device, library: library)
        // TODO: Finish
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: {
            switch self.renderPassDescriptor {
                case .`default`: return renderPassDescriptor
                case .custom(let descriptor): return descriptor
            }
        }()
        )
        guard let renderPipeline = renderPipeline else {
            fatalError("Render pipeline with vertex function \(vertexName) and fragment function \(fragmentName) not initialized. This could be because its parent's initializer was never called.")
        }

        encoder?.setRenderPipelineState(renderPipeline)
        
        vertexFunction.encode(encoder: encoder)
        fragmentFunction.encode(encoder: encoder)
        // TODO: Primitives
        encoder?.endEncoding()
        completion(self)
    }
    
    enum RenderPassDescriptor {
        /**Uses the frame's render pass descriptor–this usually is drawing to a MTLDrawable*/
        case `default`
        case custom(MTLRenderPassDescriptor)
    }
}

public struct CopyFunction: SKUnit {
    mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws {}
    
    /**The copy operation to run*/
    public var operation: (MTLBlitCommandEncoder?) -> Void
    public var completion: (Self) -> Void = { _ in }
    
    func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        operation(blitEncoder)
        blitEncoder?.endEncoding()
    }
    
    
}
