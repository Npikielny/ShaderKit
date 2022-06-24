import Metal

public protocol SKUnit {
    mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws
    func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor)
}

protocol SKShader {
    @ShaderBuilder
    func pipeline() -> SKUnit
}

struct MyShader: SKShader {
    func pipeline() -> SKUnit {
        ComputeFunction(name: "test compute")
        RenderFunction(vertexName: "copyVerts", fragmentName: "copyFrag")
        for i in 0...10 {
            CopyFunction { _ in }
        }
        CopyFunction { _ in }
        // TODO: Check if control flow messes with inialization and make sure it is not rebuilt every call.
    }
}

@resultBuilder
public struct ShaderBuilder {
    struct OpaqueShader: SKUnit {
        var initialize: (MTLDevice?, MTLLibrary?) throws -> Void
        
        var encode: (MTLCommandBuffer, MTLRenderPassDescriptor) -> Void
        
        mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws {
            let device = device ?? MTLCreateSystemDefaultDevice()
            let library = library ?? device?.makeDefaultLibrary()
            
            try initialize(device, library)
        }
        
        func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
            encode(commandBuffer, renderPassDescriptor)
        }
    }
    
    public static func buildBlock(_ components: SKUnit...) -> SKUnit {
        var components = components
        
        return OpaqueShader { device, library in
            try components.apply { component in
                try component.initialize(device: device, library: library)
            }
        } encode: { commandBuffer, renderPassDescriptor in
            components.forEach { component in
                component.encode(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            }
        }

    }
    
    public static func buildArray(_ components: [SKUnit]) -> SKUnit {
        var components = components
        
        return OpaqueShader { device, library in
            try components.apply { component in
                try component.initialize(device: device, library: library)
            }
        } encode: { commandBuffer, renderPassDescriptor in
            components.forEach { component in
                component.encode(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            }
        }

    }
    
}
