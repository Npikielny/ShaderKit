//
//  ManagedFuture.swift
//  
//
//  Created by Noah Pikielny on 7/29/22.
//

import Foundation

public class ManagedFuture<T> {
    public var result: T?
    
    public init(result: T? = nil) {
        self.result = result
    }
}
