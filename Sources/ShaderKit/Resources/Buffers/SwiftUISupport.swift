//
//  SwiftUISupport.swift
//  
//
//  Created by Noah Pikielny on 9/30/22.
//

import SwiftUI

extension Bytes {
    public init<T>(_ binding: Binding<T>) where Encoder == MTLComputeCommandEncoder {
        count = 1
        self.bytes = { encoder, index, _ in
            encoder.setBytes([binding.wrappedValue], length: MemoryLayout<T>.stride, index: index)
        }
    }
    
    public init<T>(_ binding: Binding<T>) where Encoder == MTLRenderCommandEncoder {
        count = 1
        self.bytes = { encoder, index, function in
            switch function! {
                case .fragment:
                    encoder.setFragmentBytes([binding.wrappedValue], length: MemoryLayout<T>.stride, index: index)
                case .vertex:
                    encoder.setVertexBytes([binding.wrappedValue], length: MemoryLayout<T>.stride, index: index)
            }
        }
    }
}
