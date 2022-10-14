//
//  MutableBytes.swift
//  
//
//  Created by Noah Pikielny on 9/30/22.
//

import SwiftUI

extension Bytes {
    public init<T>(_ binding: UnsafePointer<T>, count: Int) where Encoder == MTLComputeCommandEncoder {
        self.count = count
        self.bytes = { encoder, index, _ in
            encoder.setBytes(binding, length: MemoryLayout<T>.stride * count, index: index)
        }
    }
    
    public init<T>(_ binding: UnsafePointer<T>, count: Int) where Encoder == MTLRenderCommandEncoder {
        self.count = count
        self.bytes = { encoder, index, function in
            switch function! {
                case .fragment:
                    encoder.setFragmentBytes(binding, length: MemoryLayout<T>.stride * count, index: index)
                case .vertex:
                    encoder.setVertexBytes(binding, length: MemoryLayout<T>.stride * count, index: index)
            }
        }
    }
}
