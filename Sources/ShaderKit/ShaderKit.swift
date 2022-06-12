import Metal

public protocol SKUnit {
    func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor)
}

public struct ShaderKit {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}

protocol Shader {
    @ShaderBuilder
    var pipeline: SKUnit { get }
}

@resultBuilder
struct ShaderBuilder {
    struct OpaqueShader: SKUnit {
        var encode: (MTLCommandBuffer, MTLRenderPassDescriptor) -> Void
        
        func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
            encode(commandBuffer, renderPassDescriptor)
        }
    }
    
    static func buildBlock(_ components: SKUnit...) -> SKUnit {
        OpaqueShader(encode: { commandBuffer, renderPassDescriptor in
            components.forEach { shader in
                shader.encode(commandBuffer: commandBuffer, renderPassDescriptor: renderPassDescriptor)
            }
        })
    }
    
}
