//
//  RenderOperation.swift
//
//
//  Created by Noah Pikielny on 7/6/22.
//

import MetalKit

public class RenderOperation: PresentingOperation {
    var execution: RenderBuffer
    var presents: Bool
    
    public init(presents: Bool = false, shaders: [SKShader]) {
        self.presents = presents
        execution = RenderBuffer.shaders(shaders)
    }
    
    public init(presents: Bool = false, @RenderBufferBuilder renderBuffer: () throws -> RenderBuffer) rethrows {
        self.presents = presents
        self.execution = try renderBuffer()
    }
    
    public func presents(_ b: Bool) {
        presents = b
    }
    
    public func execute(commandQueue: MTLCommandQueue, drawable: MTLDrawable, renderDescriptor: MTLRenderPassDescriptor) async throws {
        try await execution.execute(
            commandQueue: commandQueue,
            renderDescriptor: renderDescriptor,
            drawable: drawable,
            presents: presents
        )
    }
}

extension RenderOperation {
    @resultBuilder
    public struct RenderBufferBuilder {
        public static func buildBlock(_ components: RenderOperationConstructor...) -> RenderBuffer {
            components.map { $0.construct() }.reduce(.empty, +)
        }
        
        public static func buildArray(_ components: [RenderOperationConstructor]) -> RenderBuffer {
            components.map { $00.construct() }.reduce(.empty, +)
        }
        
        public static func buildOptional(_ component: RenderOperationConstructor?) -> RenderBuffer {
            if let component = component {
                return component.construct()
            } else {
                return .empty
            }
        }
        
        public static func buildEither(first component: RenderOperationConstructor) -> RenderBuffer {
            component.construct()
        }
    }
}

extension RenderOperation {
    public indirect enum RenderBuffer {
        case constructors([SKConstructor])
        case shaders([SKShader])
        case mix(Self, Self)
        
        public static var empty: Self { .shaders([]) }
        
        private func concatenate(device: MTLDevice) throws -> [SKShader] {
            switch self {
                case .constructors(let array):
                    return try array.map { try $0.initialize(device: device) }
                case .shaders(let array):
                    return array
                case .mix(let commandBufferL, let commandBufferR):
                    let r = try commandBufferR.concatenate(device: device)
                    return try commandBufferL.concatenate(device: device) + r
            }
        }
        
        mutating func initialize(device: MTLDevice) throws {
            self = .shaders(try concatenate(device: device))
        }
        
        mutating private func execute(
            device: MTLDevice,
            commandBuffer: MTLCommandBuffer,
            renderDescriptor: MTLRenderPassDescriptor
        ) throws {
            if case let .shaders(shaders) = self {
                for shader in shaders {
                    if let shader = shader as? RenderPipeline {
                        shader.setRenderPassDescriptor(device: device, descriptor: renderDescriptor)
                        shader.encode(commandBuffer: commandBuffer)
                    } else {
                        shader.encode(commandBuffer: commandBuffer)
                    }
                }
            } else {
                try initialize(device: device)
                try execute(
                    device: device,
                    commandBuffer: commandBuffer,
                    renderDescriptor: renderDescriptor
                )
            }
        }
        
        mutating func execute(
            commandQueue: MTLCommandQueue,
            renderDescriptor: MTLRenderPassDescriptor,
            drawable: MTLDrawable,
            presents: Bool
        ) async throws {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw ShaderError("Unabled to make command buffer with \(commandQueue.device.name)")
            }
            try execute(
                device: commandQueue.device,
                commandBuffer: commandBuffer,
                renderDescriptor: renderDescriptor
            )
            
            if presents {
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        public static func + (lhs: Self, rhs: Self) -> Self {
            switch (lhs, rhs) {
                case let (.constructors(c1), .constructors(c2)):
                    return .constructors(c1 + c2)
                case let (.shaders(s1), .shaders(s2)):
                    return .shaders(s1 + s2)
                default:
                    return .mix(lhs, rhs)
            }
        }
    }
}

extension RenderOperation.RenderBuffer: RenderOperationConstructor {
    public func construct() -> RenderOperation.RenderBuffer {
        return self
    }
}

extension MTLCommandQueue {
    public func execute(
        renderBuffer: RenderOperation,
        renderDescriptor: MTLRenderPassDescriptor,
        drawable: MTLDrawable
    ) async throws {
        try await renderBuffer.execute(
            commandQueue: self,
            drawable: drawable,
            renderDescriptor: renderDescriptor
        )
    }
}

