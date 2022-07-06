//
//  Texture.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public struct LoadableTexture {
    public init(path: String) {
        self.path = path
    }
    
    var path: String
    
    public func texture(device: MTLDevice) -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        do {
            return try textureLoader.newTexture(URL: URL(fileURLWithPath: path))
        } catch {
            fatalError("Unable to create texture at \(path) because \n \(error.localizedDescription)")
        }
    }
}

public protocol TextureConstructor {
    func construct() -> Texture
}

public enum Texture: TextureConstructor {
    case raw(MTLTexture)
    case loadable(LoadableTexture)
    
    public static func path(_ path: String) -> Self {
        .loadable(LoadableTexture(path: path))
    }
    
    public func construct() -> Texture { self }
    
    public static func texture(_ texture: MTLTexture) -> Self { .raw(texture) }
}

extension Array where Element == Texture {
    public mutating func encode(
        device: MTLDevice,
        encoder: MTLComputeCommandEncoder
    ) {
        for (index, texture) in self.enumerated() {
            switch texture {
                case let .raw(texture):
                    encoder.setTexture(texture, index: index)
                case let .loadable(loadable):
                    let texture = loadable.texture(device: device)
                    encoder.setTexture(texture, index: index)
                    self[index] = .raw(texture)
            }
        }
    }
    
    mutating func encode(
        device: MTLDevice,
        encoder: MTLRenderCommandEncoder,
        function: RenderFunction
    ) {
        for (index, texture) in self.enumerated() {
            switch texture {
                case let .raw(texture):
                    encoder.setTexture(texture, index: index, function: function)
                case let .loadable(loadable):
                    let texture = loadable.texture(device: device)
                    encoder.setTexture(texture, index: index, function: function)
                    self[index] = .raw(texture)
            }
        }
    }
}
