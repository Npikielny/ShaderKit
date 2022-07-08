//
//  RenderBuffer.swift
//
//
//  Created by Noah Pikielny on 7/6/22.
//

import MetalKit

public class RenderBuffer: RenderOperation {
    var execution: RenderBuffer
    var presents = false
    
    public init(@RenderBufferBuilder renderBuffer: () -> RenderBuffer) {
        self.execution = renderBuffer()
    }
    
    func presents(_ b: Bool) {
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

extension RenderBuffer {
    @resultBuilder
    public struct RenderBufferBuilder {
        public static func buildBlock(_ components: SKConstructor...) -> RenderBuffer {
            .constructors(components)
        }
        
        public static func buildArray(_ components: [SKConstructor]) -> RenderBuffer {
            .constructors(components)
        }
        
        public static func buildOptional(_ component: SKConstructor?) -> RenderBuffer {
            if let component = component {
                return .constructors([component])
            } else {
                return .empty
            }
        }
        
        public static func buildEither(first component: SKConstructor) -> RenderBuffer {
            .constructors([component])
        }
        
        public static func buildBlock(_ components: SKShader...) -> RenderBuffer {
            .shaders(components)
        }
        
        public static func buildArray(_ components: [SKShader]) -> RenderBuffer {
            .shaders(components)
        }
        
        public static func buildOptional(_ component: SKShader?) -> RenderBuffer {
            if let component = component {
                return .shaders([component])
            } else {
                return .empty
            }
        }
        
        public static func buildEither(first component: SKShader) -> RenderBuffer {
            .shaders([component])
        }
        
        public static func buildBlock(_ components: RenderBuffer...) -> RenderBuffer {
            components.reduce(.empty, +)
        }
        
        public static func buildArray(_ components: [RenderBuffer]) -> RenderBuffer {
            components.reduce(.empty, +)
        }
        
        public static func buildOptional(_ component: RenderBuffer?) -> RenderBuffer {
            if let component = component {
                return component
            } else {
                return .empty
            }
        }
        
        public static func buildEither(first component: RenderBuffer) -> RenderBuffer {
            component
        }
    }
}

extension RenderBuffer {
    public indirect enum RenderBuffer {
        case constructors([SKConstructor])
        case shaders([SKShader])
        case mix(Self, Self)
        
        static var empty: Self { .shaders([]) }
        
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
                        shader.setRenderPassDescriptor(descriptor: renderDescriptor)
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
        
        static func + (lhs: Self, rhs: Self) -> Self {
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

extension MTLCommandQueue {
    func execute(
        renderBuffer: RenderBuffer,
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

