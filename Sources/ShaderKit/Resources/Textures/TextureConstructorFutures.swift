//
//  TextureConstructorFuture.swift
//  
//
//  Created by Noah Pikielny on 7/14/22.
//

import MetalKit

public struct TextureConstructorFuture: TextureConstructor {
    public var description: String?
    var create: (MTLDevice) -> Texture
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> MTLTexture) {
        self.description = description
        self.create = { Texture(create($0)) }
    }
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> TextureConstructor) {
        self.description = description
        self.create = { create($0).construct() }
    }
    
    public func enumerate() -> Texture.Representation { .future(self) }
}

public struct OptionalTextureConstructorFuture: TextureConstructor {
    public var description: String?
    var create: (MTLDevice) -> Texture?
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> MTLTexture?) {
        self.description = description
        self.create = {
            if let texture = create($0) {
                return Texture(texture)
            }
            return nil
        }
    }
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> TextureConstructor?) {
        self.description = description
        self.create = { create($0)?.construct() }
    }
    
    public func enumerate() -> Texture.Representation { .optionalFuture(self) }
}

public struct LoadableTexture: TextureConstructor {
    public init(path: String) {
        self.path = path
    }
    
    public var path: String
    public var description: String? { "Loading texture from \(path)" }
    
    public func texture(device: MTLDevice, options: [MTKTextureLoader.Option : Any]? = nil) -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        do {
            return try textureLoader.newTexture(URL: URL(fileURLWithPath: path), options: options)
        } catch {
            fatalError("Unable to create texture at \(path) because \n \(error.localizedDescription)")
        }
    }
    
    public func enumerate() -> Texture.Representation { .loadable(self) }
}
