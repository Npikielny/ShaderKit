//
//  File.swift
//  
//
//  Created by Noah Pikielny on 7/29/22.
//

import Metal

public class Future<Result>: SKShader {
    private var _result: Result? = nil
    public var description: String?
    public var result: Result {
        if let _result = _result {
            return _result
        } else {
            fatalError("Result gotten from future before it was encoded")
        }
    }
    
    private var execution: (MTLCommandBuffer) -> Result
    
    public init(_ description: String? = nil, _ execution: @escaping (MTLCommandBuffer) -> Result) {
        self.description = description
        self.execution = execution
    }
    
    public func encode(commandBuffer: MTLCommandBuffer) {
        self._result = execution(commandBuffer)
    }
    
    public func unwrap(commandBuffer: MTLCommandBuffer) -> Result {
        encode(commandBuffer: commandBuffer)
        return result
    }
}
