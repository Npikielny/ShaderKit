//
//  TextureLoader.swift
//  
//
//  Created by Noah Pikielny on 7/14/22.
//

import MetalKit

public struct TextureFuture: TextureConstructor {
    public var description: String?
    var create: (MTLDevice) -> MTLTexture
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> MTLTexture) {
        self.description = description
        self.create = create
    }
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> TextureConstructor) {
        self.description = description
        self.create = { device in
            create(device).construct().unwrap(device: device)
        }
    }
    
    public func enumerate() -> Texture.Representation { .future(self) }
}

public struct OptionalTextureFuture: TextureConstructor {
    public var description: String?
    var create: (MTLDevice) -> MTLTexture?
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> MTLTexture?) {
        self.description = description
        self.create = create
    }
    
    public init(_ description: String? = nil, _ create: @escaping (MTLDevice) -> TextureConstructor?) {
        self.description = description
        self.create = { device in
            create(device)?.construct().unwrap(device: device)
        }
    }
    
    public func enumerate() -> Texture.Representation { .optionalFuture(self) }
}

public struct LoadableTexture: TextureConstructor {
    public init(path: String) {
        self.path = path
    }
    
    public var path: String
    public var description: String? { "Loading texture from \(path)" }
    
    public func texture(device: MTLDevice) -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)
        do {
            return try textureLoader.newTexture(URL: URL(fileURLWithPath: path))
        } catch {
            fatalError("Unable to create texture at \(path) because \n \(error.localizedDescription)")
        }
    }
    
    public func enumerate() -> Texture.Representation { .loadable(self) }
}
