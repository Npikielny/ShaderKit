import Metal

public protocol SKUnit {
    func encode(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor)
}

public struct ShaderKit {
    public private(set) var text = "Hello, World!"

    public init() {
    }
}
