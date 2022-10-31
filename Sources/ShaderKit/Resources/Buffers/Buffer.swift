//
//  Buffer.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public protocol BufferConstructor {
    func construct() -> Buffer
}

public class Buffer {
    public var description: String?
    public var count: Int { representation.count }
    var representation: Representation
    
    init(_ description: String? = nil, _ representation: Representation) {
        self.description = description
        self.representation = representation
    }
    // mutable
    public init<T>(_ description: String? = nil, mutable: T, options: MTLResourceOptions? = nil) {
        self.description = description
        representation = ArrayBuffer.mutableConstant(bytes: mutable, options: options).enumerate()
    }
    
    public init<T>(_ description: String? = nil, mutable: [T], options: MTLResourceOptions? = nil) {
        self.description = description
        representation = ArrayBuffer.mutableArray(array: mutable, options: options).enumerate()
    }
    
    public init<T>(_ description: String? = nil, type: T.Type, offset: Int = 0, count: Int, options: MTLResourceOptions? = nil) {
        self.description = description
        representation = .future(Future<(MTLBuffer, Int)> { commandBuffer in
            guard let buffer = commandBuffer.device.makeBuffer(length: MemoryLayout<T>.stride * count + offset) else {
                fatalError("Unabled to make new buffer–probably not enough memory...")
            }
            
            return (buffer, count)
        })
    }
    
    public init<T>(_ description: String? = nil, mutable: UnsafeMutablePointer<T>, offset: Int = 0, count: Int, options: MTLResourceOptions? = nil) {
        self.description = description
        representation = ArrayBuffer(bytes: mutable, count: count, stride: MemoryLayout<T>.stride, offset: offset, options: options).enumerate()
    }
    
    public init<T>(_ description: String? = nil, type: T.Type, count: Int, options: MTLResourceOptions? = nil) {
        self.description = description
        representation = ArrayBuffer(
            bytes: UnsafeMutablePointer<T>.allocate(capacity: count),
            count: count,
            stride: MemoryLayout<T>.stride,
            offset: 0,
            options: options
        ).enumerate()
    }
    
    // constant
    public init<T>(_ description: String? = nil, constant: [T]) {
        self.description = description
        representation = Bytes(array: constant).enumerate()
    }
    
    public init<T>(_ description: String? = nil, constant: T) {
        self.description = description
        representation = Bytes(bytes: constant).enumerate()
    }
    
    public init<T>(_ description: String? = nil, constantPointer: UnsafeMutablePointer<T>, count: Int) {
        self.description = description
        representation = Bytes(constantPointer, stride: MemoryLayout<T>.stride, count: count).enumerate()
    }
    
    public init(_ future: Future<(MTLBuffer, Int)>) {
        description = future.description
        representation = .future(future)
    }
    
    public init(_ description: String? = nil, _ future: @escaping (MTLCommandBuffer) -> (MTLBuffer, Int)) {
        self.description = description
        representation = .future(Future<(MTLBuffer, Int)>(nil, future))
    }
    
    enum Representation {
        var count: Int {
            switch self {
                case let .raw(_, count): return count
                case let .constructor(constructor): return constructor.count
                case let .bytes(bytes): return bytes.count
                case let .future(future): return future.result.1
            }
        }
        case raw(_ buffer: MTLBuffer, _ count: Int)
        case constructor(ArrayBuffer)
        case bytes(Bytes)
        case future(Future<(MTLBuffer, Int)>)
    }
    
    public func copy(device: MTLDevice) -> Buffer {
        switch representation {
            case let .raw(buffer, count):
                return Buffer(
                    "Copy of \(description ?? "unnamed")",
                    .raw(device.makeBuffer(length: buffer.length, options: .storageModePrivate)!, count)
                )
            default:
                return Buffer("Copy of \(description ?? "unnamed")", representation)
        }
    }
    
    public func copyBytes(device: MTLDevice, bytes: UnsafeRawPointer, start: Int = 0, end: Int? = nil) {
        switch representation {
            case let .raw(buffer, _):
                let end = end ?? buffer.length
                memcpy(buffer.contents(), bytes, end - start)
                #if !os(iOS)
                if buffer.storageMode == .managed {
                    buffer.didModifyRange(start..<end)
                }
                #endif
            case let .constructor(array):
                guard let buffer = array.buffer(device) else {
                    fatalError("Unable to create buffer with device \(device)")
                }
                representation = .raw(buffer, array.count)
                copyBytes(device: device, bytes: bytes, start: start, end: end)
            default:
                fatalError("Unable to edit buffer because it is static or hasn't been created yet")
        }
    }
}

extension Buffer: BufferConstructor {
    public func construct() -> Buffer { self }
}

extension Buffer: Resource {
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        switch representation {
            case let .future(future):
                let result = future.unwrap(commandBuffer: commandBuffer, library: library)
                representation = .raw(result.0, result.1)
            default: return
        }
    }
}

struct ArrayBuffer {
    #if os(iOS)
    static let `default` = MTLResourceOptions.storageModeShared
    #else
    static let `default` = MTLResourceOptions.storageModeManaged
    #endif
    
    var description: String?
    var count: Int
    var buffer: (MTLDevice) -> MTLBuffer?
    
    static func mutableConstant<T>(bytes: T, options: MTLResourceOptions?) -> Self {
        return Self.mutableArray(array: [bytes], options: options)
    }
    
    static func mutableArray<T>(array: [T], options: MTLResourceOptions?) -> Self {
        if let array = array as? [Int] {
            return Self(bytes: array.map(Int32.init(clamping:)), count: array.count, stride: MemoryLayout<Int32>.stride, options: options)
        } else {
            return Self(bytes: array, count: array.count, stride: MemoryLayout<T>.stride, options: options ?? `default`)
        }
    }
    
    init(bytes: UnsafeRawPointer? = nil, count: Int, stride: Int, offset: Int = 0, options: MTLResourceOptions?) {
        self.count = count
        buffer = { device in
            if let bytes {
                return device.makeBuffer(bytes: bytes, length: count * stride, options: options ?? Self.default)
            } else {
                return device.makeBuffer(length: count * stride, options: options ?? Self.default)
            }
        }
    }
    
    func enumerate() -> Buffer.Representation { .constructor(self) }
}

class Bytes {
    let bytes: UnsafeRawPointer
    let size: Int
    let count: Int
    
    deinit { bytes.deallocate() }
    
    convenience init<T>(bytes: T) {
        self.init(array: [bytes])
    }
    
    convenience init<T>(array: [T]) {
        if let array = array as? [Int] {
            self.init(array.map(Int32.init(clamping:)), stride: MemoryLayout<Int32>.stride, count: array.count)
        } else {
            self.init(array, stride: MemoryLayout<T>.stride, count: array.count)
        }
    }
    
    init(_ bytes: UnsafeRawPointer, stride: Int, count: Int) {
        self.bytes = bytes
        self.size = stride * count
        self.count = count
    }
    
    func enumerate() -> Buffer.Representation {
        .bytes(self)
    }
}

protocol ConstantBufferConstructor: BufferConstructor {}

extension ConstantBufferConstructor {
    public func construct() -> Buffer {
        Buffer(constant: self)
    }
}

extension Int: ConstantBufferConstructor {}
extension Int32: ConstantBufferConstructor {}
extension Float: ConstantBufferConstructor {}

extension Array: BufferConstructor {
    public func construct() -> Buffer { Buffer(constant: self) }
}
