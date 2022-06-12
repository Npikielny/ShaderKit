//
//  Helpers.swift
//  
//
//  Created by Noah Pikielny on 6/11/22.
//

import Foundation

struct SKError: Error, CustomStringConvertible {
    var description: String
}

extension Optional {
    func logDefault (_ default: Self, message: String) -> Self {
        if let self = self { return self }
        print(message)
        return `default`
    }
    
    func logDefault (_ default: Wrapped, message: String) -> Wrapped {
        if let self = self { return self }
        print(message)
        return `default`
    }
}

extension Array {
    mutating func apply(_ transform: (inout Element) throws -> Void) rethrows {
        for i in 0..<count {
            try transform(&self[i])
        }
    }
}
