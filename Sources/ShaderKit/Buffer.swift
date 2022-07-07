//
//  Buffer.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public protocol ComputeBufferConstructor {
    func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation
}

public protocol RenderBufferConstructor {
    func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation
}

public struct ArrayBuffer<Encoder: MTLCommandEncoder> {
    var buffer: (MTLDevice) -> MTLBuffer?
    public init<T>(_ bytes: [T]) {
        buffer = { device in
            device.makeBuffer(bytes: bytes, length: MemoryLayout<T>.stride * bytes.count, options: .storageModeManaged)
        }
    }
    
    public init<T>(count: Int, type: T.Type) {
        buffer = { device in
            device.makeBuffer(length: MemoryLayout<T>.stride * count)
        }
    }
    
    public init<T>(bytes: [T], offset: Int = 0, count: Int) {
        buffer = { device in
            guard let buffer = device.makeBuffer(length: MemoryLayout<T>.stride * count, options: .storageModeManaged) else {
                return nil
            }
            memcpy(buffer.contents() + offset * MemoryLayout<T>.stride, bytes, MemoryLayout<T>.stride * bytes.count)
            return buffer
        }
    }
    
    public func enumerate() -> Buffer<Encoder>.Representation { .constructor(self) }
}

extension ArrayBuffer: ComputeBufferConstructor where Encoder == MTLComputeCommandEncoder {}
extension ArrayBuffer: RenderBufferConstructor where Encoder == MTLRenderCommandEncoder {}

public struct Bytes<Encoder: MTLCommandEncoder> {
    var bytes: (Encoder, Int) -> Void
}

extension Bytes: ComputeBufferConstructor where Encoder == MTLComputeCommandEncoder {
    public init<T>(_ array: [T]) {
        bytes = { encoder, index in
            encoder.setBytes(array, length: MemoryLayout<T>.stride * array.count, index: index)
        }
    }
    
    public init<T>(_ bytes: T) {
        self.bytes = { encoder, index in
            encoder.setBytes([bytes], length: MemoryLayout<T>.stride, index: index)
        }
    }
    public func enumerate() -> Buffer<Encoder>.Representation { .bytes(self)
    }
}

public class Buffer<Encoder: MTLCommandEncoder> {
    var representation: Representation
    
    public init(_ representation: Representation) {
        self.representation = representation
    }
    
    public init<T>(_ array: [T]) {
        representation = ArrayBuffer<Encoder>(array).enumerate()
    }
    
    public enum Representation {
        case raw(MTLBuffer)
        case constructor(ArrayBuffer<Encoder>)
        case bytes(Bytes<Encoder>)
    }
}

extension Buffer: ComputeBufferConstructor where Encoder == MTLComputeCommandEncoder {
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation { representation }
}

extension Array where Element == Buffer<MTLComputeCommandEncoder> {
    public mutating func encode(
        device: MTLDevice,
        encoder: MTLComputeCommandEncoder
    ) {
        for (index, buffer) in self.enumerated() {
            switch buffer.representation {
                case let .raw(buffer):
                    encoder.setBuffer(buffer, offset: 0, index: index)
                case let .constructor(buffer):
                    guard let buffer = buffer.buffer(device) else {
                        fatalError("Unable to create buffer with device \(device)")
                    }
                    encoder.setBuffer(buffer, offset: 0, index: index)
                    self[index].representation = .raw(buffer)
                case let .bytes(bytes):
                    bytes.bytes(encoder, index)
            }
        }
    }
}

extension Array where Element == Buffer<MTLRenderCommandEncoder> {
    mutating func encode(
        device: MTLDevice,
        encoder: MTLRenderCommandEncoder,
        renderFunction: RenderFunction
    ) {
        for (index, buffer) in self.enumerated() {
            switch buffer.representation {
                case let .raw(buffer):
                    encoder.setBuffer(buffer, offset: 0, index: index, function: renderFunction)
                case let .constructor(buffer):
                    guard let buffer = buffer.buffer(device) else {
                        fatalError("Unable to create buffer with device \(device)")
                    }
                    encoder.setBuffer(buffer, offset: 0, index: index, function: renderFunction)
                    self[index].representation = .raw(buffer)
                case let .bytes(bytes):
                    bytes.bytes(encoder, index)
            }
        }
    }
}

extension Array: ComputeBufferConstructor {
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation {
        .constructor(ArrayBuffer<MTLComputeCommandEncoder>(self))
    }
}

extension Int32: ComputeBufferConstructor {
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation {
        .bytes(.init(self))
    }
}

extension Float: ComputeBufferConstructor {
    public func enumerate() -> Buffer<MTLComputeCommandEncoder>.Representation {
        .bytes(.init(self))
    }
}
