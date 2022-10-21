import Metal

public protocol CommandOperationConstructor {
    func construct() -> CommandOperation.CommandBuffer
}

public protocol RenderOperationConstructor {
    func construct() -> RenderOperation.RenderBuffer
}

public protocol SKConstructor: CommandOperationConstructor, RenderOperationConstructor {
    func initialize(device: MTLDevice) throws -> SKShader
}

extension SKConstructor {
    public func construct() -> CommandOperation.CommandBuffer {
        .constructors([self])
    }
    
    public func construct() -> RenderOperation.RenderBuffer {
        .constructors([self])
    }
}

public protocol SKShader: CommandOperationConstructor, RenderOperationConstructor {
    func encode(commandBuffer: MTLCommandBuffer)
}

extension SKShader {
    public func construct() -> CommandOperation.CommandBuffer {
        .shaders([self])
    }
    
    public func construct() -> RenderOperation.RenderBuffer {
        .shaders([self])
    }
}

extension Array: RenderOperationConstructor where Element: RenderOperationConstructor {
    public func construct() -> RenderOperation.RenderBuffer {
        return self.reduce(.empty) { partialResult, next in
            partialResult + next.construct()
        }
    }
}

extension Array: CommandOperationConstructor where Element: CommandOperationConstructor {
    public func construct() -> CommandOperation.CommandBuffer {
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

