//
//  PointerBuffer.swift
//  Shaderkit
//
//  Created by Noah Pikielny on 5/20/23.
//

public class PointerBuffer<T: GPUEncodable> {
    typealias Pointer = UnsafeMutablePointer<T>
    var pointer: Pointer
    var count: Int
    public var buffer: Buffer
    public init(_ initalValue: [T], count: Int) {
        assert(initalValue.count == count)
        self.count = count
        self.pointer = Pointer.allocate(capacity: count)
        for i in 0..<count {
            self.pointer.advanced(by: i).pointee = initalValue[i]
        }
        self.buffer = Buffer(constantPointer: self.pointer, count: count)
    }
    
    public init(_ initalValue: T) {
        self.count = 1
        self.pointer = Pointer.allocate(capacity: 1)
        self.pointer.pointee = initalValue
        self.buffer = Buffer(constantPointer: self.pointer, count: 1)
    }
    
    public subscript(_ index: Int) -> T {
        get {
            assert(index < count)
            return pointer.advanced(by: index).pointee
        }
        set {
            assert(index < count)
            pointer.advanced(by: index).pointee = newValue
        }
    }
    
    deinit { pointer.deallocate() }
}

@propertyWrapper public struct UniformBuffer<T: GPUEncodable> {
    private var pointer: PointerBuffer<T>
    public var wrappedValue: T {
        get { pointer[0] }
        set { pointer[0] = newValue }
    }
    
    public var buffer: Buffer {
        pointer.buffer
    }
    
    public init(wrappedValue: T) {
        self.pointer = PointerBuffer(wrappedValue)
    }
    
}
