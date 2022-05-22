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


public protocol MTKViewRepresentableDelegate  {
    func updateMTKView(_ mtkView: MTKView, context: MTKViewRepresentable.Context)
}

#if os(macOS)
public struct MTKViewRepresentable: NSViewRepresentable {
    public var view: MTKView
    public var viewHandler: MTKViewRepresentableDelegate? = nil
    public var configuration: RunConfiguration = .rate(60)  {
        didSet {
            activate()
        }
    }
    
    private var timer: Timer? = nil
    
    public init(
        view: MTKView,
        viewHandler: MTKViewRepresentableDelegate? = nil,
        configuration: RunConfiguration = .rate(60),
        delegate: MTKViewDelegate? = nil
    ) {
        self.view = view
        self.viewHandler = viewHandler
        configuration.validate()
        self.configuration = configuration
        
        self.delegate = delegate
        activate()
    }
    
    public func makeNSView(context: Context) -> MTKView {
        view
    }
    
    public func updateNSView(_ nsView: MTKView, context: Context) {
        viewHandler?.updateMTKView(nsView, context: context)
    }
}
#else
public struct MTKViewRepresentable: UIViewRepresentable {
    public var view: MTKView
    public var viewHandler: MTKViewRepresentableDelegate? = nil
    public var configuration: RunConfiguration = .rate(60) {
        didSet {
            activate()
        }
    }
    
    private var timer: Timer? = nil
    
    public init(
        view: MTKView,
        viewHandler: MTKViewRepresentableDelegate? = nil,
        configuration: RunConfiguration = .rate(60),
        delegate: MTKViewDelegate? = nil
    ) {
        self.view = view
        self.viewHandler = viewHandler
        configuration.validate()
        self.configuration = configuration
        self.delegate = delegate
        
        activate()
    }
    
    func makeUIView(context: Context) -> MTKView {
        view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        viewHandler?.updateMTKView(view, context: context)
    }
}
#endif

extension MTKViewRepresentable {
    public enum RunConfiguration {
        case timer(Timer)
        case rate(_ fps: Int)
        case none
        
        func validate() {
            switch self {
                case .rate(let fps) where fps < 0:
                    fatalError("FPS must be in range 0...120, but got \(fps).")
                case .rate(let fps) where fps > 120:
                    print("FPS must be in range 0...120, but got \(fps). Will attempt to continue.")
                default: return
            }
        }
    }
    
    public var device: MTLDevice? {
        get { view.device }
        set { view.device = newValue }
    }
    
    public var delegate: MTKViewDelegate? {
        get { view.delegate }
        set { view.delegate = newValue }
    }
    
    public init?() {
        view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        configuration = .none
        
        activate()
    }
    
    public init(
        view: MTKView? = nil,
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        viewHandler: MTKViewRepresentableDelegate? = nil,
        delegate: MTKViewDelegate? = nil,
        configuration: RunConfiguration = .none
    ) {
        if let view = view {
            self.view = view
        } else {
            self.view = MTKView()
        }
        
        self.viewHandler = viewHandler
        self.configuration = configuration
        self.device = device
        self.delegate = delegate
        
        activate()
    }
    
    mutating private func activate() {
        timer?.invalidate()
        switch configuration {
            case .timer(let timer):
                self.timer = timer
            case .rate(let fps):
                self.timer = Timer.scheduledTimer(withTimeInterval: 1 / Double(fps), repeats: true) { [self] _ in
                    delegate?.draw(in: view)
                }
            case .none:
                timer = nil
        }
    }
}
