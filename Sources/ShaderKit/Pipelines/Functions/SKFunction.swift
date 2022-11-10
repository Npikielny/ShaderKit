//
//  SKFunction.swift
//  
//
//  Created by Noah Pikielny on 10/25/22.
//

import Metal

enum PipelineRepresentation<T: Pipeline> {
    case pipeline(T.Pipeline)
    case constructor(T.Constructor)
}

protocol Pipeline: CustomStringConvertible, AnyObject {
    associatedtype Constructor
    associatedtype Pipeline
    var representation: PipelineRepresentation<Self> { get set }
    
    static func construct(device: MTLDevice, library: MTLLibrary, constructor: Constructor) throws -> Pipeline
}

extension Pipeline {
    func unwrap(device: MTLDevice, library: MTLLibrary) throws -> (description: String, pipeline: Pipeline) {
        switch self.representation {
            case let .constructor(constructor):
                let pipeline = try Self.construct(device: device, library: library, constructor: constructor)
                self.representation = .pipeline(pipeline)
                return (description, pipeline)
            case let .pipeline(pipeline):
                return (description, pipeline)
        }
    }
    
    static func makeFunction(device: MTLDevice, library: MTLLibrary, name: String, constants: MTLFunctionConstantValues?) throws -> MTLFunction? {
        if let constants {
            return try library.makeFunction(name: name, constantValues: constants)
        } else {
            return library.makeFunction(name: name)
        }
    }
}

public final class RenderFunction: Pipeline {
    typealias Pipeline = MTLRenderPipelineState
    typealias Constructor = (vertex: String, fragment: String, format: RenderPipelineDescriptor)
    
    var representation: PipelineRepresentation<RenderFunction>
    public var description: String
    
    init(description: String, representation: PipelineRepresentation<RenderFunction>) {
        self.description = description
        self.representation = representation
    }
    
    public convenience init(description: String? = nil, vertex: String, fragment: String, destination: Texture) {
        self.init(description: description, vertex: vertex, fragment: fragment, destination: .texture(destination))
    }
    
    public convenience init(description: String? = nil, vertex: String, fragment: String, format: MTLPixelFormat) {
        self.init(description: description, vertex: vertex, fragment: fragment, destination: .pixelFormat(format))
    }
    
    init(description: String?, vertex: String, fragment: String, destination: RenderPipelineDescriptor) {
        representation = .constructor((vertex, fragment, destination))
        self.description = description ?? "(\(vertex), \(fragment))"
    }
    
    static func construct(device: MTLDevice, library: MTLLibrary, constructor: Constructor) throws -> Pipeline {
        let descriptor = MTLRenderPipelineDescriptor()
        guard let vertex = try Self.makeFunction(
            device: device,
            library: library,
            name: constructor.vertex,
            constants: nil
        ) else {
            throw ShaderError("Unable to make vertex shader of \(constructor)")
        }
        guard let fragment = try Self.makeFunction(
                device: device,
                library: library,
                name: constructor.fragment,
                constants: nil
              ) else {
            throw ShaderError("Unable to make fragment shader of \(constructor)")
        }
        
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        switch constructor.format {
            case let .pixelFormat(format):
                descriptor.colorAttachments[0].pixelFormat = format
            case let .texture(texture):
                descriptor.colorAttachments[0].pixelFormat = texture.unwrap(device: device).pixelFormat
        }
        
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}

public final class ComputeFunction: Pipeline {
    typealias Constructor = (name: String, constants: MTLFunctionConstantValues?)
    typealias Pipeline = MTLComputePipelineState
    
    var representation: PipelineRepresentation<ComputeFunction>
    
    public var description: String
    
    public convenience init(name: String, constants: MTLFunctionConstantValues? = nil, description: String? = nil) {
        self.init(representation: .constructor((name, constants)), description: description ?? name)
    }
    
    init(representation: PipelineRepresentation<ComputeFunction>, description: String) {
        self.representation = representation
        self.description = description
    }
    
    static func construct(device: MTLDevice, library: MTLLibrary, constructor: (name: String, constants: MTLFunctionConstantValues?)) throws -> Pipeline {
        guard let function = try makeFunction(
            device: device,
            library: library,
            name: constructor.name,
            constants: constructor.constants
        ) else {
            throw ShaderError("Unable to make function \(constructor.name) with constants \(constructor.constants ?? MTLFunctionConstantValues())")
        }
        return try device.makeComputePipelineState(function: function)
    }
}
