//
//  Buffer.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public protocol ComputeBufferConstructor {
    var count: Int { get }
    func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation
}

extension ComputeBufferConstructor {
    public func construct(_ description: String? = nil) -> Buffer<MTLComputeCommandEncoder> {
        Buffer(description, self.enumerate())
    }
}

public class Buffer<Encoder: MTLCommandEncoder> {
    public var description: String?
    public var count: Int { representation.count }
    var representation: Representation
    
    public init(_ description: String? = nil, _ representation: Representation) {
        self.description = description
        self.representation = representation
    }
    
    public init<T>(_ description: String? = nil, _ array: [T]) {
        self.description = description
        representation = ArrayBuffer<Encoder>(array).enumerate()
    }
    
    public init(_ description: String? = nil, _ bytes: Bytes<Encoder>) {
        self.description = description
        representation = .bytes(bytes)
    }
    
    public init(_ future: Future<(MTLBuffer, Int)>) {
        description = future.description
        representation = .future(future)
    }
    
    public init(_ description: String? = nil, _ future: @escaping (MTLCommandBuffer) -> (MTLBuffer, Int)) {
        self.description = description
        representation = .future(Future<(MTLBuffer, Int)>(nil, future))
    }
    
    public enum Representation {
        var count: Int {
            switch self {
                case let .raw(_, count): return count
                case let .constructor(constructor): return constructor.count
                case let .bytes(bytes): return bytes.count
                case let .future(future): return future.result.1
            }
        }
        case raw(MTLBuffer, Int)
        case constructor(ArrayBuffer<Encoder>)
        case bytes(Bytes<Encoder>)
        case future(Future<(MTLBuffer, Int)>)
    }
    
    public func copy(device: MTLDevice) -> Buffer<Encoder> {
        switch representation {
            case let .raw(buffer, count):
                return Buffer<Encoder>(
                    "Copy of \(description ?? "unnamed")",
                    .raw(device.makeBuffer(length: buffer.length, options: .storageModePrivate)!, count)
                )
            default:
                return Buffer<Encoder>("Copy of \(description ?? "unnamed")", representation)
        }
    }
}

extension Buffer: Resource {
    public func encode(commandBuffer: MTLCommandBuffer) {
        switch representation {
            case let .future(future):
                let result = future.unwrap(commandBuffer: commandBuffer)
                representation = .raw(result.0, result.1)
            default: return
        }
    }
}

extension Buffer: ComputeBufferConstructor where Encoder == MTLComputeCommandEncoder {
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation {
        representation
    }
    
    public convenience init(_ constructor: ComputeBufferConstructor) {
        self.init(constructor.enumerate())
    }
    
    public convenience init<T>(_ bytes: T) {
        self.init(
            nil,
            .bytes(Bytes(bytes))
        )
    }
}

extension Buffer: RenderBufferConstructor where Encoder == MTLRenderCommandEncoder {
    public func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation {
        representation
    }
    
    public convenience init(_ constructor: RenderBufferConstructor) {
        self.init(
            nil,
            constructor.enumerate()
        )
    }
}


public struct ArrayBuffer<Encoder: MTLCommandEncoder> {
    public var description: String?
    public var count: Int
    var buffer: (MTLDevice) -> MTLBuffer?
    
    public init<T>(_ bytes: [T]) {
        count = bytes.count
        buffer = { device in
            #if os(iOS)
            device.makeBuffer(bytes: bytes, length: MemoryLayout<T>.stride * bytes.count, options: .storageModeShared)
            #else
            device.makeBuffer(bytes: bytes, length: MemoryLayout<T>.stride * bytes.count, options: .storageModeManaged)
            #endif
        }
    }
    
    public init<T>(count: Int, type: T.Type) {
        self.count = count
        buffer = { device in
            device.makeBuffer(length: MemoryLayout<T>.stride * count)
        }
    }
    
    public init<T>(bytes: [T], offset: Int = 0, count: Int) {
        self.count = count
        buffer = { device in
            #if os(iOS)
            guard let buffer = device.makeBuffer(length: MemoryLayout<T>.stride * count, options: .storageModeShared) else {
                return nil
            }
            #else
            guard let buffer = device.makeBuffer(length: MemoryLayout<T>.stride * count, options: .storageModeManaged) else {
                return nil
            }
            #endif
            memcpy(buffer.contents() + offset * MemoryLayout<T>.stride, bytes, MemoryLayout<T>.stride * bytes.count)
            return buffer
        }
    }
    
    public func enumerate() -> Buffer<Encoder>.Representation { .constructor(self) }
}

extension ArrayBuffer: ComputeBufferConstructor where Encoder == MTLComputeCommandEncoder {}
extension ArrayBuffer: RenderBufferConstructor where Encoder == MTLRenderCommandEncoder {}

public struct Bytes<Encoder: MTLCommandEncoder> {
    public var count: Int
    var bytes: (Encoder, Int, RenderFunction?) -> Void
}

extension Bytes: ComputeBufferConstructor where Encoder == MTLComputeCommandEncoder {
    public init<T: ComputeBufferConstructor>(_ array: [T]) {
        count = array.count
        bytes = { encoder, index, _ in
            encoder.setBytes(array, length: MemoryLayout<T>.stride * array.count, index: index)
        }
    }
    
    public init(_ array: [Int]) {
        count = array.count
        bytes = { encoder, index, _ in
            encoder.setBytes(array.map { Int32($0) }, length: MemoryLayout<Int32>.stride * array.count, index: index)
        }
    }
    
    public init<T>(_ bytes: T) {
        count = 1
        self.bytes = { encoder, index, _ in
            encoder.setBytes([bytes], length: MemoryLayout<T>.stride, index: index)
        }
    }
    
    public init<T>(_ bytes: @escaping () -> T) {
        count = 1
        self.bytes = { encoder, index, _ in
            encoder.setBytes([bytes()], length: MemoryLayout<T>.stride, index: index)
        }
    }
    public func enumerate() -> Buffer<Encoder>.Representation { .bytes(self) }
}

extension Array where Element == Buffer<MTLComputeCommandEncoder> {
    public mutating func encode(
        commandBuffer: MTLCommandBuffer,
        encoder: MTLComputeCommandEncoder
    ) {
        
        for (index, buffer) in self.enumerated() {
            switch buffer.representation {
                case let .raw(buffer, _):
                    encoder.setBuffer(buffer, offset: 0, index: index)
                case let .constructor(constructor):
                    guard let buffer = constructor.buffer(commandBuffer.device) else {
                        fatalError("Unable to create buffer with device \(commandBuffer.device)")
                    }
                    encoder.setBuffer(buffer, offset: 0, index: index)
                    self[index].representation = .raw(buffer, constructor.count)
                case let .bytes(bytes):
                    bytes.bytes(encoder, index, nil)
                case .future(let future):
                    let buffer = future.unwrap(commandBuffer: commandBuffer)
                    self[index].representation = .raw(buffer.0, buffer.1)
                    encoder.setBuffer(buffer.0, offset: 0, index: index)
            }
        }
    }
}

extension Array: ComputeBufferConstructor where Element: ComputeBufferConstructor {
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation {
        .constructor(ArrayBuffer<MTLComputeCommandEncoder>(self))
    }
}

extension Int32: ComputeBufferConstructor {
    public var count: Int { 1 }
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation { .bytes(.init(self)) }
}

extension Int: ComputeBufferConstructor {
    public var count: Int { 1 }
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation { .bytes(.init(Int32(self)))}
}

extension Float: ComputeBufferConstructor {
    public var count: Int { 1 }
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation { .bytes(.init(self)) }
}

extension Bool: ComputeBufferConstructor {
    public var count: Int { 1 }
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation { .bytes(.init(self)) }
}
