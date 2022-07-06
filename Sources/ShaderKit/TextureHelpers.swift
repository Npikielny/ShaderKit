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
            return .raw(texture)
        } else {
            return nil
        }
    }
}

extension Texture {
    public static func newTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        storageMode: MTLStorageMode,
        read: Bool = false,
        write: Bool = false,
        renderTarget: Bool = false
    ) -> Texture? {
        newTexture(
            device: device,
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
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage
    ) -> Texture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.width = width
        descriptor.height = height
        descriptor.storageMode = storageMode
        descriptor.usage = usage
        return device.makeTexture(descriptor: descriptor).wrap()
    }
    
    public static func newTexture(
        device: MTLDevice,
        texture: inout Texture,
        pixelFormat: MTLPixelFormat? = nil,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage
    ) -> Texture? {
        let descriptor = MTLTextureDescriptor()
        let texture = texture.unwrap(device: device)
        if let pixelFormat = pixelFormat {
            descriptor.pixelFormat = pixelFormat
        } else {
            descriptor.pixelFormat = texture.pixelFormat
        }
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.storageMode = storageMode
        descriptor.usage = usage
        return device.makeTexture(descriptor: descriptor).wrap()
    }
    
    public static func newTexture(
        device: MTLDevice,
        texture: MTLTexture,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage
    ) -> Texture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = texture.pixelFormat
        descriptor.width = texture.width
        descriptor.height = texture.height
        descriptor.storageMode = storageMode
        descriptor.usage = usage
        return device.makeTexture(descriptor: descriptor).wrap()
    }
}
