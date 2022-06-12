////
////  File.swift
////  
////
////  Created by Noah Pikielny on 5/18/22.
////
//
//import MetalKit
//import SwiftUI
//
//public class PipelineRenderer: Renderer {
//    private var pipelines: [ExecuteablePipeline]!
//    
//    public init?(
//        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
//        threadCount: Int = 1,
//        delegate: RendererDelegate?,
//        pipelines: [Pipeline]
//    ) throws {
//        super.init(device: device, threadCount: threadCount, delegate: delegate)
//        
//        guard let pipelines = try pipelines.map(convertPipeline(_:)).unwrap() else { return nil }
//        self.pipelines = pipelines
//    }
//    
//    enum ExecuteablePipeline {
//        case compute(MTLComputePipelineState)
//        case render
//    }
//    
//    private func convertPipeline(_ pipeline: Pipeline) throws -> ExecuteablePipeline? {
//        switch pipeline {
//            case .compute(let name, let constants):
//                guard let computePipeline = try computePipeline(name: name, constants: constants) else { return nil }
//                return .compute(computePipeline)
//            case .render: return .render
//        }
//    }
//    
//    public enum Pipeline {
//        case compute(name: String, _ constants: MTLFunctionConstantValues? = nil)
//        case render
//    }
//    
//    public func draw(in view: MTKView, with commandBuffer: MTLCommandBuffer?) {
//        
//    }
//}
//
//extension Array {
//    internal func unwrap<ElementOfResult>() -> [ElementOfResult]? where Self.Element == ElementOfResult? {
//        return contains { $0 == nil } ? nil : map { $0! }
//    }
//}
