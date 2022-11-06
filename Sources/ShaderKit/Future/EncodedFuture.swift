//
//  File.swift
//  
//
//  Created by Noah Pikielny on 7/29/22.
//

import Metal

public class EncodedFuture<Result>: SKShader {
    public typealias Execution = (_ commandBuffer: MTLCommandBuffer) -> Result
    
    private var _result: Result? = nil
    public var description: String?
    public var result: Result {
        if let _result = _result {
            return _result
        } else {
            fatalError("Result gotten from future before it was encoded")
        }
    }
    
    private var execution: Execution
    
    public init(_ description: String? = nil, _ execution: @escaping Execution) {
        self.description = description
        self.execution = execution
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        self._result = execution(commandBuffer)
    }
    
    public func unwrap(commandBuffer: MTLCommandBuffer, library: MTLLibrary) -> Result {
        encode(commandBuffer: commandBuffer, library: library)
        return result
    }
}

public class Future<Result>: SKShader {
    public typealias Execution = (_ device: MTLDevice) -> Result
    
    private var _result: Result? = nil
    public var description: String?
    public var result: Result {
        if let _result = _result {
            return _result
        } else {
            fatalError("Result gotten from future before it was encoded")
        }
    }
    
    private var execution: Execution
    
    public init(_ description: String? = nil, _ execution: @escaping Execution) {
        self.description = description
        self.execution = execution
    }
    
    public func encode(device: MTLDevice) {
        self._result = execution(device)
    }
    
    public func unwrap(device: MTLDevice) -> Result {
        encode(device: device)
        return result
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        encode(device: commandBuffer.device)
    }
}
