//
//  TextureHelpers.swift
//  
//
//  Created by Noah Pikielny on 7/6/22.
//

import MetalKit

extension Optional where Wrapped == MTLTexture {
    func wrap() -> Texture? {
        if let texture = self {
            return Texture(texture)
        } else {
            return nil
        }
    }
}

extension TextureConstructor {
    public static func newTexture(
        name: String? = nil,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        depth: Int = 1,
        storageMode: MTLStorageMode,
        read: Bool = false,
        write: Bool = false,
        renderTarget: Bool = false
    ) -> Texture {
        newTexture(
            name: name,
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            depth: depth,
            storageMode: storageMode,
            usage: MTLTextureUsage(
                [] +
                (renderTarget ? [.renderTarget] : []) +
                (read ? [.shaderRead] : []) +
                (write ? [.shaderWrite] : [])
            )
        )
    }
    
    public static func newTexture(
        name: String? = nil,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        depth: Int = 1,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage
    ) -> Texture {
        OptionalTextureConstructorFuture(name) { device -> Texture? in
            let descriptor = MTLTextureDescriptor()
            
            var virtualSRGB = false
            
            if pixelFormat == .rgba8Unorm_srgb &&
                (usage.contains(.shaderWrite)) {
                descriptor.pixelFormat = .rgba8Unorm
                virtualSRGB = true
            } else if pixelFormat == .bgra8Unorm_srgb &&
                        (usage.contains(.shaderWrite))  {
                descriptor.pixelFormat = .bgra8Unorm
                virtualSRGB = true
            } else {
                descriptor.pixelFormat = pixelFormat
            }
            
            descriptor.textureType = depth > 1 ? .type3D : .type2D
            
            descriptor.depth = depth
            descriptor.width = width
            descriptor.height = height
            descriptor.storageMode = storageMode
            descriptor.usage = usage
            return Texture(device.makeTexture(descriptor: descriptor), virtualSRGB)
        }.construct()
    }
    
    public func emptyCopy(
        name: String? = nil,
        pixelFormat: MTLPixelFormat? = nil,
        storageMode: MTLStorageMode? = nil,
        width: Int? = nil,
        height: Int? = nil,
        depth: Int? = nil,
        usage: MTLTextureUsage? = nil
    ) -> Texture {
        // FIXME: Cycle
        let name = name ?? "Copy of \(self.description ?? "unnamed")"
        return TextureConstructorFuture(name) { [self] device -> TextureConstructor in
            let texture = construct().unwrap(device: device)
            
            return Texture.newTexture(
                name: name,
                pixelFormat: pixelFormat ?? texture.pixelFormat,
                width: width ?? texture.width,
                height: height ?? texture.height,
                depth: depth ?? texture.depth,
                storageMode: storageMode ?? texture.storageMode,
                usage: usage ?? texture.usage
            )
        }.construct()
    }
}

extension MTLTextureUsage {
    public var compute: Self { [.shaderRead, .shaderWrite] }
    
    public var readWrite: Self { compute }
    
    public var all: Self { [compute, .renderTarget] }
}
