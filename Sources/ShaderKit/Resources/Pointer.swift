//
//  Pointer.swift
//  
//
//  Created by Noah Pikielny on 7/15/22.
//

import Metal

public class RawPointer<T> {
    public let pointer: UnsafeMutablePointer<T>
    
    public init(_ pointer: UnsafeMutablePointer<T>) {
        self.pointer = pointer
    }
    
    public subscript(_ index: Int) -> T {
        pointer[index]
    }
    
    func write(to: URL, count: Int, options: Data.WritingOptions? = nil) throws {
        try Data(bytes: pointer, count: count).write(to: to, options: [])
    }
}

public class ArrayPointer<T> {
    var pointer: RawPointer<T>
    var count: Int
    
    public init(pointer: RawPointer<T>, count: Int) {
        self.pointer = pointer
        self.count = count
    }
    
    public init(_ buffer: Buffer, device: MTLDevice, type: T.Type, count: Int) {
        self.pointer = RawPointer(buffer
            .unwrap(device: device)
            .contents()
            .bindMemory(to: type, capacity: count))
        
        self.count = count
    }
    
    public subscript(_ index: Int) -> T {
        pointer[index]
    }
}

extension ArrayPointer: Sequence {
    public func makeIterator() -> Iterator {
        Iterator(pointer: pointer, count: count)
    }
    
    public struct Iterator: IteratorProtocol {
        let pointer: RawPointer<T>
        var start = 0
        var count: Int
        public typealias Element = T
        
        mutating public func next() -> Element? {
            if self.start >= self.count { return nil }
            self.start += 1
            return pointer[self.start - 1]
        }
    }
}

extension MTLBuffer {
    func bytes<T>(to: T.Type, count: Int) -> RawPointer<T> {
        RawPointer(contents().bindMemory(to: to, capacity: count))
    }
}

extension Buffer {
    func bytes<T>(to: T.Type, device: MTLDevice) -> RawPointer<T> {
        switch self.representation {
            case let .raw(buffer, count):
                return buffer.bytes(to: to, count: count)
            case let .pointer(pointer, _, count):
                let mutablePointer = UnsafeMutablePointer(mutating: pointer.bindMemory(to: T.self, capacity: count))
                return RawPointer(mutablePointer)
            case let .future(future):
                let result = future.result
                return result.0.bytes(to: to, count: result.1)
            case .bytes(_):
                fatalError("Cannot unwrap constant/static resources")
            case .encodedFuture(_):
                fatalError("Can't unwrap encoded futures–any chance you don't need a command buffer to create this?")
        }
    }
}

public class TexturePointer<T: SIMDScalar> {
    public let pointer: RawPointer<T>
    private let width: Int
    private let components: Int
    
    public init(_ pointer: RawPointer<T>, components: Int, width: Int) {
        self.pointer = pointer
        self.width = width
        self.components = components
    }
    
    public convenience init(_ pointer: UnsafeMutablePointer<T>, components: Int, width: Int) {
        self.init(RawPointer(pointer), components: components, width: width)
    }
    
    public subscript(_ index: Int) -> T {
        pointer[index]
    }
    
    public subscript(x: Int, y: Int) -> [T] {
        let index = x * components + y * width * components
        return Array(0..<components).map { self[index + $0] }
    }
}

extension MTLTexture {
    // source: https://stackoverflow.com/a/63035123
    func getPixels<T>(_ region: MTLRegion? = nil, mipmapLevel: Int = 0, components: Int) -> RawPointer<T> {
        let fromRegion  = region ?? MTLRegionMake2D(0, 0, self.width, self.height)
        let width       = fromRegion.size.width
        let height      = fromRegion.size.height
        let bytesPerRow = MemoryLayout<T>.stride * width * components
        let data        = UnsafeMutablePointer<T>.allocate(capacity: bytesPerRow * height)

        getBytes(data, bytesPerRow: bytesPerRow, from: fromRegion, mipmapLevel: mipmapLevel)
        return RawPointer<T>(data)
      }
}

extension Texture {
    public func bytes<T: SIMDScalar>(
        device: MTLDevice,
        type: T.Type,
        components: Int,
        region: MTLRegion?,
        mipMapLevel: Int
    ) -> TexturePointer<T> {
        let texture = unwrap(device: device)
        let pointer: RawPointer<T> = texture.getPixels(region, mipmapLevel: mipMapLevel, components: components)
        return TexturePointer<T>(
            pointer,
            components: components,
            width: texture.width
        )
    }
    
    public func floatBytes(device: MTLDevice, components: Int, region: MTLRegion?, mipMapLevel: Int) -> TexturePointer<Float> {
        bytes(device: device, type: Float.self, components: components, region: region, mipMapLevel: mipMapLevel)
    }
    
    public func intBytes(device: MTLDevice, components: Int, region: MTLRegion?, mipMapLevel: Int) -> TexturePointer<Int32> {
        bytes(device: device, type: Int32.self, components: components, region: region, mipMapLevel: mipMapLevel)
    }
}
