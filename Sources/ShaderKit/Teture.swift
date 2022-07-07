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
    func enumerate() -> Texture.Representation
}

extension TextureConstructor {
    func construct() -> Texture {
        .init(enumerate())
    }
}

public class Texture: TextureConstructor {
    var representation: Representation
    
    public init(_ constructor: TextureConstructor) {
        representation = constructor.enumerate()
    }
    
    public init(_ texture: MTLTexture) {
        representation = .raw(texture)
    }
    
    public func enumerate() -> Representation {
        representation
    }
}

extension Texture {
    public enum Representation: TextureConstructor {
        case raw(MTLTexture)
        case loadable(LoadableTexture)
        
        public static func path(_ path: String) -> Self {
            .loadable(LoadableTexture(path: path))
        }
        
        public func enumerate() -> Representation { self }
    }
    
    public func unwrap(device: MTLDevice) -> MTLTexture {
        switch representation {
            case .raw(let texture):
                return texture
            case .loadable(let loadableTexture):
                let texture = loadableTexture.texture(device: device)
                representation = .raw(texture)
                return texture
        }
    }
    
    public func width(device: MTLDevice) -> Int {
        unwrap(device: device).width
    }
    
    public func height(device: MTLDevice) -> Int {
        unwrap(device: device).height
    }
    
    public func pixelFormat(device: MTLDevice) -> MTLPixelFormat {
        unwrap(device: device).pixelFormat
    }
}

extension String: TextureConstructor {
    public func enumerate() -> Texture.Representation {
        .loadable(LoadableTexture(path: self))
    }
}

extension Array where Element == Texture {
    public mutating func encode(
        device: MTLDevice,
        encoder: MTLComputeCommandEncoder
    ) {
        for (index, texture) in self.enumerated() {
            switch texture.representation {
                case let .raw(texture):
                    encoder.setTexture(texture, index: index)
                case let .loadable(loadable):
                    let texture = loadable.texture(device: device)
                    encoder.setTexture(texture, index: index)
                    self[index].representation = .raw(texture)
            }
        }
    }
    
    mutating func encode(
        device: MTLDevice,
        encoder: MTLRenderCommandEncoder,
        function: RenderFunction
    ) {
        for (index, texture) in self.enumerated() {
            switch texture.representation {
                case let .raw(texture):
                    encoder.setTexture(texture, index: index, function: function)
                case let .loadable(loadable):
                    let texture = loadable.texture(device: device)
                    encoder.setTexture(texture, index: index, function: function)
                    self[index].representation = .raw(texture)
            }
        }
    }
}
