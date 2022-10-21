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
    
    deinit {
        pointer.deallocate()
    }
    
    func write(to: URL, count: Int, options: Data.WritingOptions? = nil) throws {
        try Data(bytes: pointer, count: count).write(to: to, options: [])
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
            case let .constructor(array):
                guard let buffer = array.buffer(device) else {
                    fatalError("Unable to create buffer with device \(device)")
                }
                representation = .raw(buffer, array.count)
                return buffer.bytes(to: to, count: array.count)
            case .bytes(_):
                fatalError("Cannot unwrap constant/static resources")
            case let .future(future):
                let result = future.result
                return result.0.bytes(to: to, count: result.1)
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

extension MTLPixelFormat {
    var channels: Int {
        switch self {
            case .a8Unorm, .r8Unorm, .r8Unorm_srgb, .r8Snorm, .r8Uint, .r8Sint, .r16Unorm, .r16Snorm, .r16Uint, .r16Sint, .r16Float, .r32Uint, .r32Sint, .r32Float:
                return 1
            case .rg8Unorm, .rg8Unorm_srgb, .rg8Snorm, .rg8Uint, .rg8Sint, .rg16Unorm, .rg16Snorm, .rg16Uint, .rg16Sint, .rg16Float, .rg32Uint, .rg32Sint, .rg32Float:
                return 2
            case .b5g6r5Unorm, .a1bgr5Unorm, .rg11b10Float:
                return 3
            case .abgr4Unorm, .bgr5A1Unorm, .rgba8Unorm, .rgba8Unorm_srgb, .rgba8Snorm, .rgba8Uint, .rgba8Sint, .bgra8Unorm, .bgra8Unorm_srgb, .rgb10a2Unorm, .rgb10a2Uint, .bgr10a2Unorm, .rgba16Unorm, .rgba16Snorm, .rgba16Uint, .rgba16Sint, .rgba16Float, .rgba32Uint, .rgba32Sint, .rgba32Float:
                return 4
            default:
                fatalError("Unimplemented pixel type \(self)")
        }
    }
    
    
}
