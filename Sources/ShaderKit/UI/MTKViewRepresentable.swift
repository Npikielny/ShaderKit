//
//  MTKViewRepresentable.swift
//  
//
//  Created by Noah Pikielny on 5/18/22.
//

import MetalKit
import SwiftUI
#if os(iOS)
import UIKit
#endif
public enum Configuration {
    case rate(_ fps: Int)
    case timer(Timer)
    case none
}
#if os(macOS)
public struct MTKViewRepresentable: NSViewRepresentable {
    var view: MTKView
    public var delegate: MTKViewDelegate? {
        didSet {
            view.delegate = delegate
        }
    }
    
    public var device: MTLDevice? {
        get { view.device }
        set { view.device = newValue }
    }
    
    public func makeNSView(context: Context) -> MTKView {
        view
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {}
}
#elseif os(iOS)
public struct MTKViewRepresentable: UIViewRepresentable {
    var view: MTKView
    public var delegate: MTKViewDelegate? {
        get { view.delegate }
        set { view.delegate = newValue }
    }
    
    public var device: MTLDevice? {
        get { view.device }
        set { view.device = newValue }
    }
    
    public func makeUIView(context: Context) -> MTKView {
        view
    }
    
    public func updateUIView(_ nsView: MTKView, context: Context) {}
}
#endif

extension MTKViewRepresentable {
    public var currentDrawable: CAMetalDrawable? {
        view.currentDrawable
    }
    
    public var nextDrawable: CAMetalDrawable? {
        (view.layer as? CAMetalLayer)?.nextDrawable()
    }
    
    public var currentRenderPassDescriptor: MTLRenderPassDescriptor? {
        view.currentRenderPassDescriptor
    }
    
    public func draw() {
        delegate?.draw(in: view)
    }
    
    public func getConfiguration(_ configuration: Configuration) -> Configuration {
        switch configuration {
            case .rate(let rate):
                let timer = Timer.scheduledTimer(withTimeInterval: 1 / Double(rate), repeats: true) { _ in
                    self.draw()
                }
                return .timer(timer)
            default:
                return configuration
        }
    }
    
    public init(
        view: MTKView,
        delegate: MTKViewDelegate? = nil,
        device: MTLDevice? = nil,
        configuration: Configuration? = nil,
        pixelFormat: MTLPixelFormat? = nil
    ) {
        self.view = view
        if let pixelFormat {
            view.colorPixelFormat = pixelFormat
        }
        self.delegate = delegate
        self.device = device
        
        if let configuration = configuration,
           case let .timer(timer) = getConfiguration(configuration) {
            timer.fire()
        }
    }
    
    public init(
        frame: CGRect,
        delegate: MTKViewDelegate? = nil,
        device: MTLDevice? = nil,
        configuration: Configuration? = nil,
        pixelFormat: MTLPixelFormat? = nil
    ) {
        self.view = MTKView(frame: frame)
        self.delegate = delegate
        self.device = device
        
        if let pixelFormat {
            view.colorPixelFormat = pixelFormat
        }
        
        if let configuration = configuration,
           case let .timer(timer) = getConfiguration(configuration) {
            timer.fire()
        }
    }
}

// MARK: - ShaderKit Interfacing
public protocol ShaderDelegate: AnyObject {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
}

extension MTKViewRepresentable {
    public class ShaderDelegateInterface: NSObject, MTKViewDelegate {
        public var operation: PresentingOperation
        public weak var delegate: ShaderDelegate?
        public var device: MTLDevice? {
            didSet {
                setCommandQueue(device: device)
            }
        }
        private lazy var library: MTLLibrary? = device?.makeDefaultLibrary()
        
        var commandQueue: MTLCommandQueue?
        
        public init(operation: PresentingOperation, device: MTLDevice?) {
            self.operation = operation
            self.device = device
            super.init()
            setCommandQueue(device: device)
        }
        
        func setCommandQueue(device: MTLDevice?) {
            guard let device = device else { commandQueue = nil; return }
            commandQueue = device.makeCommandQueue()
        }
        
        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            delegate?.mtkView(view, drawableSizeWillChange: size)
        }
        
        public func draw(in view: MTKView) {
            guard let commandQueue,
                  let library,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            Task {
                try await operation.execute(
                    commandQueue: commandQueue,
                    library: library,
                    drawable: drawable,
                    renderDescriptor: renderPassDescriptor
                )
            }
        }
        
        public func asyncDraw(in view: MTKViewRepresentable) async throws {
            guard let commandQueue,
                  let library,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            try await operation.execute(
                commandQueue: commandQueue,
                library: library,
                drawable: drawable,
                renderDescriptor: renderPassDescriptor
            )
        }
        
        public func asyncDraw(in view: MTKViewRepresentable, with commandQueue: MTLCommandQueue) async throws {
            guard let drawable = view.currentDrawable,
                  let library,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
            
            try await operation.execute(
                commandQueue: commandQueue,
                library: library,
                drawable: drawable,
                renderDescriptor: renderPassDescriptor
            )
        }
    }
    
    public init(
        view: MTKView,
        operation: PresentingOperation,
        device: MTLDevice? = nil,
        configuration: Configuration? = nil,
        pixelFormat: MTLPixelFormat? = nil
    ) {
        self.view = view
        
        if let pixelFormat {
            self.view.colorPixelFormat = pixelFormat
        }
        delegate = ShaderDelegateInterface(operation: operation, device: device)
        self.device = device
        
        if let configuration = configuration,
           case let .timer(timer) = getConfiguration(configuration) {
            timer.fire()
        }
    }
    
    public init(
        frame: CGRect,
        operation: PresentingOperation,
        device: MTLDevice? = nil,
        configuration: Configuration? = nil,
        pixelFormat: MTLPixelFormat? = nil
    ) {
        self.view = MTKView(frame: frame)
        if let pixelFormat {
            self.view.colorPixelFormat = pixelFormat
        }
        delegate = ShaderDelegateInterface(operation: operation, device: device)
        self.device = device
        
        if let configuration = configuration,
           case let .timer(timer) = getConfiguration(configuration) {
            timer.fire()
        }
    }
}
