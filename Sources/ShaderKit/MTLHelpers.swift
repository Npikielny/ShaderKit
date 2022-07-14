//
//  File.swift
//  
//
//  Created by Noah Pikielny on 7/8/22.
//

import Metal

extension MTLSize {
    func threadGroupCount(dispatchWidth: Int, dispatchHeight: Int) -> MTLSize {
        MTLSize(
            width: (dispatchWidth + width - 1) / width,
            height: (dispatchHeight + height - 1) / height,
            depth: 1
        )
    }
}
