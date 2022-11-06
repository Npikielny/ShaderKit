//
//  CommandEncoder.swift
//  
//
//  Created by Noah Pikielny on 10/25/22.
//

import Metal

enum CommandEncoder {
    case compute(_ encoder: MTLComputeCommandEncoder)
    case render(_ encoder: MTLRenderCommandEncoder)
    
    func setBuffers(commandBuffer: MTLCommandBuffer, library: MTLLibrary, buffers: inout [Buffer], function: EncodingFunction) {
        for (index, buffer) in buffers.enumerated() {
            switch buffer.representation {
                case let .raw(buffer, _):
                    setBuffer(buffer, offset: 0, index: index, function: function)
                case let .bytes(bytes):
                    setBytes(bytes.bytes, length: bytes.size, index: index, function: function)
                case let .future(future):
                    let buffer = future.unwrap(device: commandBuffer.device)
                    buffers[index].representation = .raw(buffer.0, buffer.1)
                    setBuffer(buffer.0, offset: 0, index: index, function: function)
                case let .encodedFuture(future):
                    let buffer = future.unwrap(commandBuffer: commandBuffer, library: library)
                    buffers[index].representation = .raw(buffer.0, buffer.1)
                    setBuffer(buffer.0, offset: 0, index: index, function: function)
                case let .pointer(pointer, stride, count):
                    setBytes(pointer, length: stride * count, index: index, function: function)
            }
        }
    }
    func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int, function: EncodingFunction) {
        switch self {
            case .compute(let encoder):
                encoder.setBuffer(buffer, offset: offset, index: index)
            case .render(let encoder):
                switch function {
                    case .compute: fatalError()
                    case .vertex: encoder.setVertexBuffer(buffer, offset: offset, index: index)
                    case .fragment: encoder.setFragmentBuffer(buffer, offset: offset, index: index)
                }
        }
    }
    func setBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int, function: EncodingFunction) {
        switch self {
            case let .compute(encoder): encoder.setBytes(bytes, length: length, index: index)
            case let .render(encoder):
                switch function {
                    case .compute: fatalError()
                    case .vertex: encoder.setVertexBytes(bytes, length: length, index: index)
                    case .fragment: encoder.setFragmentBytes(bytes, length: length, index: index)
                }
        }
    }
    
    func setTextures(device: MTLDevice, textures: [Texture], function: EncodingFunction) {
        let textures = textures.map { texture in
            return texture.unwrap(device: device)
        }
        switch self {
            case let .compute(encoder):
                encoder.setTextures(textures, range: 0..<textures.count)
            case let .render(encoder):
                switch function {
                    case .compute: fatalError()
                    case .vertex: encoder.setVertexTextures(textures, range: 0..<textures.count)
                    case .fragment: encoder.setFragmentTextures(textures, range: 0..<textures.count)
                }
        }
    }
}

extension MTLRenderCommandEncoder {
    var wrapped: CommandEncoder { .render(self) }
}

extension MTLComputeCommandEncoder {
    var wrapped: CommandEncoder { .compute(self) }
}
