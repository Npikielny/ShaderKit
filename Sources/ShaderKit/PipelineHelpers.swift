//
//  PipelineHelpers.swift
//  
//
//  Created by Noah Pikielny on 6/11/22.
//

import Metal

extension SKFunction {
    mutating func setRuntimeResources(_ encode: @escaping (CommandEncoder?) -> ()) {
        runtimeResources = encode
    }
    
    mutating func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int) {
        buffers.append((buffer, offset, index))
    }
    
    mutating func setBuffers(_ buffers: [MTLBuffer], offsets: [Int], range: Range<Int>) {
        for (index, rangeIndex) in range.enumerated() {
            setBuffer(buffers[index], offset: offsets[index], index: rangeIndex)
        }
    }
    
    mutating func setTexture(_ texture: MTLTexture, index: Int) {
        textures.append((texture, index))
    }
    
    mutating func setTextures(_ textures: [MTLTexture], range: Range<Int>) {
        for (index, rangeIndex) in range.enumerated() {
            setTexture(textures[index], index: rangeIndex)
        }
    }
}

extension SKFunction where CommandEncoder == MTLComputeCommandEncoder {
    mutating func setConstant<T>(_ value: Array<T>, index: Int) {
        constants.append { encoder in
            encoder?.setBytes(value, length: MemoryLayout<T>.stride * value.count, index: index)
        }
    }
    
    mutating func setConstant<T>(_ value: T, index: Int) {
        constants.append { encoder in
            encoder?.setBytes([value], length: MemoryLayout<T>.stride, index: index)
        }
    }
}

extension RenderFunction {
    typealias Component = RenderFunctionComponent.Component
    
    internal subscript(_ component: Component) -> RenderFunctionComponent {
        get {
            switch component {
                case .vertex: return vertexFunction
                case .fragment: return fragmentFunction
            }
        }
        set {
            switch component {
                case .vertex: vertexFunction = newValue
                case .fragment: fragmentFunction = newValue
            }
        }
    }
    
    // TODO: Fix
//    mutating func setRuntimeResources(_ encode: @escaping (MTLComputeCommandEncoder?) -> (), component: RenderFunctionComponent.Component) {
//        runtimeResources = encode
//    }
    
    mutating func setBuffer(_ buffer: MTLBuffer, offset: Int, index: Int, component: Component) {
        self[component].buffers.append((buffer, offset, index))
    }
    
    mutating func setBuffers(_ buffers: [MTLBuffer], offsets: [Int], range: Range<Int>, component: Component) {
        for (index, rangeIndex) in range.enumerated() {
            setBuffer(buffers[index], offset: offsets[index], index: rangeIndex, component: component)
        }
    }
    
    mutating func setTexture(_ texture: MTLTexture, index: Int, component: Component) {
        self[component].textures.append((texture, index))
    }
    
    mutating func setTextures(_ textures: [MTLTexture], range: Range<Int>, component: Component) {
        for (index, rangeIndex) in range.enumerated() {
            self[component].setTexture(textures[index], index: rangeIndex)
        }
    }
    
    mutating func setConstant<T>(_ value: Array<T>, index: Int, component: Component) {
        self[component].constants.append { encoder in
            encoder?.setBytes(value, length: MemoryLayout<T>.stride * value.count, index: index, component: component)
        }
    }
    
    mutating func setConstant<T>(_ value: T, index: Int, component: Component) {
        self[component].constants.append { encoder in
            encoder?.setBytes([value], length: MemoryLayout<T>.stride, index: index, component: component)
        }
    }
}
