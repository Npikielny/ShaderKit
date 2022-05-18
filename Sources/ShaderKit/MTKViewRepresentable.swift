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


protocol MTKViewRepresentableDelegate  {
    func updateMTKView(_ mtkView: MTKView, context: MTKViewRepresentable.Context)
}

#if os(macOS)
struct MTKViewRepresentable: NSViewRepresentable {
    var view: MTKView
    var viewHandler: MTKViewRepresentableDelegate? = nil
    var configuration: RunConfiguration = .rate(60)  {
        didSet {
            activate()
        }
    }
    
    private var timer: Timer? = nil
    
    init(
        view: MTKView,
        viewHandler: MTKViewRepresentableDelegate? = nil,
        configuration: RunConfiguration = .rate(60)
    ) {
        self.view = view
        self.viewHandler = viewHandler
        configuration.validate()
        self.configuration = configuration
        
        activate()
    }
    
    func makeNSView(context: Context) -> MTKView {
        view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        viewHandler?.updateMTKView(nsView, context: context)
    }
}
#else
struct MTKViewRepresentable: UIViewRepresentable {
    var view: MTKView
    var viewHandler: MTKViewRepresentableDelegate? = nil
    var configuration: RunConfiguration = .rate(60) {
        didSet {
            activate()
        }
    }
    
    private var timer: Timer? = nil
    
    init(
        view: MTKView,
        viewHandler: MTKViewRepresentableDelegate? = nil,
        configuration: RunConfiguration = .rate(60)
    ) {
        self.view = view
        self.viewHandler = viewHandler
        configuration.validate()
        self.configuration = configuration
        
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
    enum RunConfiguration {
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
    
    var device: MTLDevice? {
        get { view.device }
        set { view.device = newValue }
    }
    
    var delegate: MTKViewDelegate? {
        get { view.delegate }
        set { view.delegate = newValue }
    }
    
    init?() {
        view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        configuration = .none
        
        activate()
    }
    
    init(
        view: MTKView? = nil,
        device: MTLDevice? = MTLCreateSystemDefaultDevice(),
        viewHandler: MTKViewRepresentableDelegate? = nil,
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
