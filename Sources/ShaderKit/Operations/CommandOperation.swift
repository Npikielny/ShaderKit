//
//  CommandOperation.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public class CommandOperation: Operation {
    var execution: CommandBuffer

    public init(shaders: [SKShader]) {
        self.execution = CommandBuffer.shaders(shaders)
    }
    
    public init(@CommandBufferBuilder commandBuffer: () throws -> CommandBuffer) rethrows {
        self.execution = try commandBuffer()
    }

    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws {
        try await execution.execute(commandQueue: commandQueue, library: library)
    }
}

extension CommandOperation {
    @resultBuilder
    public struct CommandBufferBuilder {
        public static func buildBlock(_ components: CommandOperationConstructor...) -> CommandBuffer {
            components.map { $0.construct() }.reduce(.empty, +)
        }
        
        public static func buildArray(_ components: [CommandOperationConstructor]) -> CommandBuffer {
            components.map { $0.construct() }.reduce(.empty, +)
        }
        
        public static func buildOptional(_ component: CommandOperationConstructor?) -> CommandBuffer {
            if let component = component {
                return component.construct()
            } else {
                return .empty
            }
        }
        
        public static func buildEither(first component: CommandOperationConstructor) -> CommandBuffer {
            component.construct()
        }
    }
}

extension CommandOperation {
    public indirect enum CommandBuffer: CommandOperationConstructor {
        case constructors([SKConstructor])
        case shaders([SKShader])
        case mix(CommandBuffer, CommandBuffer)

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

        mutating private func execute(device: MTLDevice, library: MTLLibrary, commandBuffer: MTLCommandBuffer) throws {
            if case let .shaders(shaders) = self {
                for index in 0..<shaders.count {
                    shaders[index].encode(commandBuffer: commandBuffer, library: library)
                }
            } else {
                try initialize(device: device)
                try execute(device: device, library: library, commandBuffer: commandBuffer)
            }
        }

        mutating func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws {
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw ShaderError("Unabled to make command buffer with \(commandQueue.device.name)")
            }
            try execute(device: commandQueue.device, library: library, commandBuffer: commandBuffer)
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
        
        public func construct() -> Self {
            self
        }
    }
}

extension MTLCommandQueue {
    public func execute(commandBuffer: CommandOperation, library: MTLLibrary? = nil) async throws {
        guard let library = library ?? device.makeDefaultLibrary() else {
            throw ShaderError("Unable to make library")
        }
        try await commandBuffer.execution.execute(commandQueue: self, library: library)
    }
    
    public func execute(@CommandOperation.CommandBufferBuilder commandBuffer: () -> CommandOperation.CommandBuffer) async throws {
        try await execute(commandBuffer: CommandOperation(commandBuffer: commandBuffer))
    }
}
