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

extension Texture {
    public static func newTexture(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        storageMode: MTLStorageMode,
        read: Bool = false,
        write: Bool = false,
        renderTarget: Bool = false
    ) -> TextureConstructor {
        newTexture(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
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
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage
    ) -> TextureConstructor {
        OptionalTextureFuture { device -> MTLTexture? in
            let descriptor = MTLTextureDescriptor()
            
            if pixelFormat == .rgba8Unorm_srgb && usage.contains(.shaderWrite) || usage.contains(.renderTarget) {
                descriptor.pixelFormat = .rgba8Unorm
            } else if pixelFormat == .bgra8Unorm_srgb && usage.contains(.shaderWrite) || usage.contains(.renderTarget)  {
                descriptor.pixelFormat = .bgra8Unorm
            } else {
                descriptor.pixelFormat = pixelFormat
            }
            
            descriptor.width = width
            descriptor.height = height
            descriptor.storageMode = storageMode
            descriptor.usage = usage
            return device.makeTexture(descriptor: descriptor)
        }
    }
    
    public func emptyCopy(
        pixelFormat: MTLPixelFormat? = nil,
        storageMode: MTLStorageMode? = nil,
        usage: MTLTextureUsage? = nil
    ) -> TextureConstructor {
        // FIXME: Cycle
        TextureFuture { [self] device -> TextureConstructor in
            let texture = unwrap(device: device)
            
            return Texture.newTexture(
                pixelFormat: pixelFormat ?? texture.pixelFormat,
                width: texture.width,
                height: texture.height,
                storageMode: storageMode ?? texture.storageMode,
                usage: usage ?? texture.usage
            )
        }
    }
}

extension MTLTextureUsage {
    var compute: Self {
        [.shaderRead, .shaderWrite]
    }
    var readWrite: Self { compute }
    
    var all: Self {
        [compute, .renderTarget]
    }
}
