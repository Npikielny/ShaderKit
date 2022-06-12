import Metal

protocol SKUnit {
    mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws
    func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor)
}

protocol Shader {
    @ShaderBuilder
    var pipeline: SKUnit { get }
    func initialize(device: MTLDevice?, library: MTLLibrary?)
}

@resultBuilder
struct ShaderBuilder {
    struct OpaqueShader: SKUnit {
        var initialize: (MTLDevice?, MTLLibrary?) throws -> Void
        
        var encode: (MTLCommandBuffer, MTLRenderPassDescriptor) -> Void
        
        mutating func initialize(device: MTLDevice?, library: MTLLibrary?) throws {
            try initialize(device, library)
        }
        
        func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
            encode(commandBuffer, renderPassDescriptor)
        }
    }
    
    static func buildBlock(_ components: SKUnit...) -> SKUnit {
        var components = components
        
        return OpaqueShader { device, library in
            
            let device = device ?? MTLCreateSystemDefaultDevice()
            let library = library ?? device?.makeDefaultLibrary()
            
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
