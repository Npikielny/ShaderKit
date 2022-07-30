//
//  File.swift
//  
//
//  Created by Noah Pikielny on 7/26/22.
//

import Metal

public protocol RenderBufferConstructor {
    func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation
}

extension Bytes: RenderBufferConstructor where Encoder == MTLRenderCommandEncoder {
    public init<T: ComputeBufferConstructor>(_ array: [T]) {
        count = array.count
        bytes = { encoder, index, function in
            switch function! {
                case .fragment:
                    encoder.setFragmentBytes(array, length: MemoryLayout<T>.stride * array.count, index: index)
                case .vertex:
                    encoder.setVertexBytes(array, length: MemoryLayout<T>.stride * array.count, index: index)
            }
        }
    }
    
    public init(_ array: [Int]) {
        count = array.count
        let array = array.map { Int32($0) }
        bytes = { encoder, index, function in
            switch function! {
                case .fragment:
                    encoder.setFragmentBytes(array, length: MemoryLayout<Int32>.stride * array.count, index: index)
                case .vertex:
                    encoder.setVertexBytes(array, length: MemoryLayout<Int32>.stride * array.count, index: index)
            }
        }
    }
    
    public init<T>(_ bytes: T) {
        count = 1
        self.bytes = { encoder, index, function in
            switch function! {
                case .fragment:
                    encoder.setFragmentBytes([bytes], length: MemoryLayout<T>.stride, index: index)
                case .vertex:
                    encoder.setVertexBytes([bytes], length: MemoryLayout<T>.stride, index: index)
            }
        }
    }
    public func enumerate() -> Buffer<Encoder>.Representation { .bytes(self) }
}

extension Array where Element == Buffer<MTLRenderCommandEncoder> {
    mutating func encode(
        commandBuffer: MTLCommandBuffer,
        encoder: MTLRenderCommandEncoder,
        function: RenderFunction
    ) {
        for (index, buffer) in self.enumerated() {
            switch buffer.representation {
                case let .raw(buffer, _):
                    encoder.setBuffer(buffer, offset: 0, index: index, function: function)
                case let .constructor(constructor):
                    guard let buffer = constructor.buffer(commandBuffer.device) else {
                        fatalError("Unable to create buffer with device \(commandBuffer.device)")
                    }
                    encoder.setBuffer(buffer, offset: 0, index: index, function: function)
                    self[index].representation = .raw(buffer, constructor.count)
                case let .bytes(bytes):
                    bytes.bytes(encoder, index, function)
                case let .future(future):
                    let result = future.unwrap(commandBuffer: commandBuffer)
                    self[index].representation = .raw(result.0, result.1)
                    encoder.setBuffer(result.0, offset: 0, index: index, function: function)
            }
        }
    }
}

extension Array: RenderBufferConstructor where Element: RenderBufferConstructor {
    public func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation {
        .constructor(ArrayBuffer<MTLRenderCommandEncoder>(self))
    }
}

extension Int32: RenderBufferConstructor {
    public func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation { .bytes(.init(self)) }
}

extension Int: RenderBufferConstructor {
    public func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation { .bytes(.init(Int32(self)))}
}

extension Float: RenderBufferConstructor {
    public func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation { .bytes(.init(self)) }
}

extension Bool: RenderBufferConstructor {
    public func enumerate() -> Buffer<MTLRenderCommandEncoder>.Representation { .bytes(.init(self)) }
}
