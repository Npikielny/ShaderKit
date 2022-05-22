//
//  File.swift
//  
//
//  Created by Noah Pikielny on 5/18/22.
//

import MetalKit

public typealias Renderer = BaseRenderer & RendererDelegate

public protocol RendererDelegate: NSObject {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    func draw(in view: MTKView, with commandBuffer: MTLCommandBuffer?)
}

public class BaseRenderer: NSObject {
    public var device: MTLDevice?
    public lazy var queue: MTLCommandQueue? = device?.makeCommandQueue()
    public var semaphore: DispatchSemaphore
    
    public var delegate: RendererDelegate?
    /**
    - Parameters:
        - device: GPU for rendering
        - threadCount: number of threads, ≥ 1
     */
    public init(
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        threadCount: Int = 1,
        delegate: RendererDelegate?
    ) {
        self.device = device
        semaphore = DispatchSemaphore(value: max(threadCount, 1))
        self.delegate = delegate
    }
    
    // MARK: - MTLFunctions
    public lazy var library: MTLLibrary? = device?.makeDefaultLibrary()
    
    public func makeFunction(name: String) -> MTLFunction? {
        library?.makeFunction(name: name)
    }
    
    public func makeFunction(name: String, constants: MTLFunctionConstantValues) throws -> MTLFunction? {
        try library?.makeFunction(name: name, constantValues: constants)
    }
    
    // MARK: - Pipelines
    public func computePipeline(name: String, constants: MTLFunctionConstantValues? = nil) throws -> MTLComputePipelineState? {
        guard let function = try { () throws -> MTLFunction? in
            if let constants = constants {
                return try makeFunction(name: name, constants: constants)
            } else {
                return makeFunction(name: name)
            }
        }() else { return nil }
        
        return try device?.makeComputePipelineState(function: function)
    }
    
    public func computePipeline(function: MTLFunction?) throws -> MTLComputePipelineState? {
        guard let function = function else { return nil }
        return try device?.makeComputePipelineState(function: function)
    }
    
}

extension BaseRenderer: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        delegate?.mtkView(view, drawableSizeWillChange: size)
    }
    
    public func draw(in view: MTKView) {
        semaphore.wait()
        let commandBuffer = queue?.makeCommandBuffer()
        commandBuffer?.addCompletedHandler { _ in
            self.semaphore.signal()
        }
        
        delegate?.draw(in: view, with: commandBuffer)
        
        commandBuffer?.commit()
    }
}

// MARK: - Statics
extension BaseRenderer {
    public static var device: MTLDevice? = MTLCreateSystemDefaultDevice()
    public static var library: MTLLibrary? = device?.makeDefaultLibrary()
    
    public static func makeFunction(name: String) -> MTLFunction? {
        library?.makeFunction(name: name)
    }
    
    public static func makeFunction(name: String, constants: MTLFunctionConstantValues) throws {
        try library?.makeFunction(name: name, constantValues: constants)
    }
}
