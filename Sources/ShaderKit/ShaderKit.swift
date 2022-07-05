import Metal

public protocol SKConstructor {
    func initialize(device: MTLDevice) throws -> SKShader
}

public protocol SKShader {
    func encode(commandBuffer: MTLCommandBuffer)
}

internal struct ShaderError: Error, CustomStringConvertible {
    var localizedDescription: String
    
    internal init(_ error: String) {
        localizedDescription = error
    }
    
    var description: String { localizedDescription }
}

