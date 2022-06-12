//
//  SKPipeline.swift
//  
//
//  Created by Noah Pikielny on 6/11/22.
//

import Metal

public struct ComputeFunction: SKFunction {
    var textures: [(texture: MTLTexture, index: Int)]
    var buffers: [(buffer: MTLBuffer, offset: Int, index: Int)]
    var constants: [(MTLCommandEncoder?) -> Void]
    var runtimeResources: (MTLCommandEncoder?) -> Void
    var pipeline: MTLComputePipelineState
    
    public var completion: (Self) -> Void
    public func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
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
    var textures: [(texture: MTLTexture, index: Int)]
    var buffers: [(buffer: MTLBuffer, offset: Int, index: Int)]
    var constants: [(MTLRenderCommandEncoder?) -> Void]
    var runtimeResources: (MTLRenderCommandEncoder?) -> Void
    
    var component: Component
    
    public var completion: (Self) -> Void
    
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
    var vertexFunction: RenderFunctionComponent
    var fragmentFunction: RenderFunctionComponent
    
    var renderPipeline: MTLRenderPipelineState
    
    var renderPassDescriptor: RenderPassDescriptor = .default
    var completion: (_ function: Self) -> Void
    
    public func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: {
            switch self.renderPassDescriptor {
                case .default: return renderPassDescriptor
                case .custom(let descriptor): return descriptor
            }
        }()
        )
        encoder?.setRenderPipelineState(renderPipeline)
        
        vertexFunction.encode(encoder: encoder)
        fragmentFunction.encode(encoder: encoder)
        // TODO: Primitives
        encoder?.endEncoding()
        completion(self)
    }
    
    enum RenderPassDescriptor {
        case `default`
        case custom(MTLRenderPassDescriptor)
    }
}
