//
//  SKFunction.swift
//  
//
//  Created by Noah Pikielny on 6/11/22.
//

import Metal

internal protocol SKFunction: SKUnit {
    associatedtype CommandEncoder: MTLCommandEncoder
    var textures: [(texture: MTLTexture, index: Int)] { get set }
    var buffers: [(buffer: MTLBuffer, offset: Int, index: Int)] { get set }
    var constants: [(CommandEncoder?) -> Void] { get set }
    var runtimeResources: (CommandEncoder?) -> Void { get set }
    var completion: (_ function: Self) -> Void { get }
}
