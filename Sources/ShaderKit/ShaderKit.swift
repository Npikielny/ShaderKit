import Metal

public protocol CommandBufferConstructor {
    func construct() -> CommandBuffer.CommandBuffer
}

public protocol RenderCommandBufferConstructor {
    func construct() -> RenderBuffer.RenderBuffer
}

public protocol SKConstructor: CommandBufferConstructor, RenderCommandBufferConstructor {
    func initialize(device: MTLDevice) throws -> SKShader
}

extension SKConstructor {
    public func construct() -> CommandBuffer.CommandBuffer {
        .constructors([self])
    }
    
    public func construct() -> RenderBuffer.RenderBuffer {
        .constructors([self])
    }
}

public protocol SKShader: CommandBufferConstructor, RenderCommandBufferConstructor {
    func encode(commandBuffer: MTLCommandBuffer)
}

extension SKShader {
    public func construct() -> CommandBuffer.CommandBuffer {
        .shaders([self])
    }
    
    public func construct() -> RenderBuffer.RenderBuffer {
        .shaders([self])
    }
}

extension Array: RenderCommandBufferConstructor where Element: RenderCommandBufferConstructor {
    public func construct() -> RenderBuffer.RenderBuffer {
        return self.reduce(.empty) { partialResult, next in
            partialResult + next.construct()
        }
    }
}

extension Array: CommandBufferConstructor where Element: CommandBufferConstructor {
    public func construct() -> CommandBuffer.CommandBuffer {
        return self.reduce(.empty) { partialResult, next in
            partialResult + next.construct()
        }
    }
}

internal struct ShaderError: Error, CustomStringConvertible {
    var localizedDescription: String
    
    internal init(_ error: String) {
        localizedDescription = error
    }
    
    var description: String { localizedDescription }
}

