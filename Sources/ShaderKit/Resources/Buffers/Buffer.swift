//
//  Buffer.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public class Buffer {
#if os(iOS)
static let `default` = MTLResourceOptions.storageModeShared
#else
static let `default` = MTLResourceOptions.storageModeManaged
#endif
    
    public var description: String?
    public var count: Int { representation.count }
    var representation: Representation
    
    init(_ description: String? = nil, _ representation: Representation) {
        self.description = description
        self.representation = representation
    }
    
    // mutable
    public convenience init(_ description: String? = nil, mutable: any Bytes, options: MTLResourceOptions? = nil) {
        self.init(description) { commandBuffer in
            guard let buffer = commandBuffer.device.makeBuffer(
                bytes: mutable.bytes,
                length: mutable.size * mutable.count,
                options: options ?? Self.default
            )
            else { fatalError("Unabled to make new buffer–probably not enough memory...") }
            return (buffer, mutable.count)
        }
    }
    
    public convenience init<T>(_ description: String? = nil, mutable: (any Bytes)?, type: T.Type, offset: Int = 0, count: Int, options: MTLResourceOptions? = nil) {
        self.init(description) { commandBuffer in
            guard let buffer = commandBuffer.device.makeBuffer(length: MemoryLayout<T>.stride * count + offset) else {
                fatalError("Unabled to make new buffer–probably not enough memory...")
            }
            if let mutable {
                memcpy(buffer.contents() + offset, mutable.bytes, mutable.size * mutable.count)
            }
            
            return (buffer, count)
        }
    }
    
    public init(_ description: String? = nil, future: @escaping EncodedFuture<(MTLBuffer, Int)>.Execution) {
        self.description = description
        representation = .encodedFuture(EncodedFuture<(MTLBuffer, Int)>(description, future))
    }
    
    public init(_ future: EncodedFuture<(MTLBuffer, Int)>) {
        description = future.description
        representation = .encodedFuture(future)
    }
    
    public init(_ description: String? = nil, future: @escaping Future<(MTLBuffer, Int)>.Execution) {
        self.description = description
        representation = .future(Future<(MTLBuffer, Int)>(description, future))
    }
    
    public init(_ future: Future<(MTLBuffer, Int)>) {
        description = future.description
        representation = .future(future)
    }
    
    // constant
    public init(_ description: String? = nil, constant: any Bytes) {
        self.description = description
        representation = .bytes(constant)
    }
    
    public init<T>(_ description: String? = nil, constantPointer: UnsafeMutablePointer<T>, count: Int) {
        self.description = description
        representation = .pointer(constantPointer, MemoryLayout<T>.stride, count)
    }
    
    public init(_ description: String? = nil, _ future: @escaping (MTLCommandBuffer) -> (MTLBuffer, Int)) {
        self.description = description
        representation = .encodedFuture(EncodedFuture<(MTLBuffer, Int)>(nil, future))
    }
    
    enum Representation {
        var count: Int {
            switch self {
                case let .raw(_, count), let .pointer(_, _, count): return count
                case let .bytes(bytes): return bytes.count
                case let .future(future): return future.result.1
                case let .encodedFuture(future): return future.result.1
            }
        }
        case raw(_ buffer: MTLBuffer, _ count: Int)
        case bytes(any Bytes)
        case pointer(UnsafeRawPointer, _ stride: Int, _ count: Int)
        case encodedFuture(EncodedFuture<(MTLBuffer, Int)>)
        case future(Future<(MTLBuffer, Int)>)
    }
    
//    public func copy(device: MTLDevice) -> Buffer {
//        switch representation {
//            case let .raw(buffer, count):
//                return Buffer(
//                    "Copy of \(description ?? "unnamed")",
//                    .raw(device.makeBuffer(length: buffer.length, options: .storageModePrivate)!, count)
//                )
//            default:
//                return Buffer("Copy of \(description ?? "unnamed")", representation)
//        }
//    }
    
    public func unwrap(device: MTLDevice) -> MTLBuffer {
        switch self.representation {
            case let .raw(buffer, _):
                return buffer
            case let .future(future):
                return future.unwrap(device: device).0
            default:
                fatalError("Resource not stored on the GPU")
        }
    }
    
    public func copyBytes(device: MTLDevice, bytes: UnsafeRawPointer, start: Int = 0, end: Int? = nil) {
        
        let buffer = unwrap(device: device)
        let end = end ?? buffer.length
        memcpy(buffer.contents(), bytes, end - start)
#if !os(iOS)
        if buffer.storageMode == .managed {
            buffer.didModifyRange(start..<end)
        }
#endif
    }
}

extension Buffer {
    struct CustomEncodable<T>: Bytes {
        var bytes: [T]
        
        init(bytes: [T]) {
            self.bytes = bytes
        }
        
        init(bytes: T) {
            self.bytes = [bytes]
        }
    }
}

extension Buffer: Resource {
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        switch representation {
            case let .encodedFuture(future):
                let result = future.unwrap(commandBuffer: commandBuffer, library: library)
                representation = .raw(result.0, result.1)
            case let .future(future):
                let result = future.unwrap(device: commandBuffer.device)
                representation = .raw(result.0, result.1)
            default: return
        }
    }
}

public protocol Bytes {
    associatedtype GPUElement
    
    var bytes: [GPUElement] { get }
}

extension Bytes {
    var count: Int { bytes.count }
    var size: Int { MemoryLayout<GPUElement>.stride }
}
extension Array: Bytes where Element: GPUEncodable {
    public typealias GPUElement = Element.GPUElement
    
    public var bytes: [GPUElement] {
        return self.map(Element.bytesMap)
    }
}

public protocol GPUEncodable: Bytes where GPUElement == Self {
    static func bytesMap(_ elt: Self) -> GPUElement
}

extension GPUEncodable {
    public var bytes: [GPUElement] { [self] }
    
    public static func bytesMap(_ elt: Self) -> GPUElement {
        elt
    }
}

extension Int: Bytes {
    public typealias GPUElement = Int32
    
    public var bytes: [GPUElement] { [Int32(self)] }
}
extension Int32: GPUEncodable {}
extension Float: GPUEncodable {}
