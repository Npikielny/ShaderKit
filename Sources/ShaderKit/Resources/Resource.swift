//
//  Resource.swift
//  
//
//  Created by Noah Pikielny on 7/29/22.
//

import Metal

public protocol Resource {
    func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary)
}
