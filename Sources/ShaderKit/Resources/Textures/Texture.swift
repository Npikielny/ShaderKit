//
//  Texture.swift
//  FluidLensing
//
//  Created by Noah Pikielny on 6/29/22.
//

import MetalKit

public protocol TextureConstructor {
    var description: String? { get }
    func enumerate() -> Texture.Representation
}

extension TextureConstructor {
    public func construct() -> Texture {
        if let self = self as? Texture { return self }
        return .init(enumerate())
    }
}

public class Texture: TextureConstructor {
    public var description: String?
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
        case future(TextureConstructorFuture)
        case optionalFuture(OptionalTextureConstructorFuture)
        
        public static func path(_ path: String) -> Self {
            .loadable(LoadableTexture(path: path))
        }
        
        public func enumerate() -> Representation { self }
        
        public var description: String? {
            switch self {
                case .raw(let rep): return rep.description
                case .loadable(let rep): return rep.description
                case .future(let rep): return rep.description
                case .optionalFuture(let rep): return rep.description
            }
        }
        
    }
    
    public func unwrap(device: MTLDevice) -> MTLTexture {
        switch representation {
            case let .raw(texture):
                return texture
            case let .loadable(loadableTexture):
                let texture = loadableTexture.texture(device: device)
                representation = .raw(texture)
                return texture
            case let .future(future):
                let texture = future.create(device)
                representation = texture.representation
                return unwrap(device: device)
            case let .optionalFuture(future):
                guard let texture = future.create(device) else {
                    fatalError("Failed unwrapping \(future.description ?? "unnamed texture")")
                }
                representation = texture.representation
                return unwrap(device: device)
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
    public var description: String? { self }
    
    public func enumerate() -> Texture.Representation {
        .loadable(LoadableTexture(path: self))
    }
    
    public func construct(options: LoadableTexture.OptionSet) -> Texture {
        LoadableTexture(path: self, options: options).construct()
    }
}

extension Array where Element == Texture {
    public mutating func encode(
        device: MTLDevice,
        encoder: MTLComputeCommandEncoder
    ) {
        for (index, texture) in self.enumerated() {
            let texture = texture.unwrap(device: device)
            encoder.setTexture(texture, index: index)
        }
    }
    
    mutating func encode(
        device: MTLDevice,
        encoder: MTLRenderCommandEncoder,
        function: RenderFunction
    ) { 
        for (index, texture) in self.enumerated() {
            let texture = texture.unwrap(device: device)
            encoder.setTexture(texture, index: index, function: function)
        }
    }
}
