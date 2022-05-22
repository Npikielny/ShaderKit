//
//  CopyPipeline.swift
//  
//
//  Created by Noah Pikielny on 5/22/22.
//

import MetalKit

extension BaseRenderer {
    public func createCopyPipeline(pixelFormat: MTLPixelFormat) -> CopyPipeline? {
        CopyPipeline(device: device, pixelFormat: pixelFormat)
    }
}

public struct CopyPipeline {
    internal var pipeline: MTLRenderPipelineState
    public init?(device: MTLDevice?, pixelFormat: MTLPixelFormat) {
        do {
            let library = try device?.makeLibrary(source: Self.libraryString, options: nil)
            guard let vertexFunction = library?.makeFunction(name: "copyVertex"),
                  let fragmentFunction = library?.makeFunction(name: "copyFragment") else {
                      print("failed making shaders"); return nil
                  }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.sampleCount = 1
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            guard let pipeline = try device?.makeRenderPipelineState(descriptor: descriptor) else {
                print("Failed making pipeline"); return nil
            }
            self.pipeline = pipeline
        } catch {
            print(error); return nil
        }
    }
    
    static let libraryString =
"""
// used to render the entire screen
constant float2 cornerVerts[] = {
    // top left
    float2(-1, -1),
    float2(-1,  1),
    float2( 1, 1),
    // bottom right
    float2(-1, -1),
    float2( 1,  1),
    float2( 1, -1),
};

struct VertOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertOut copyVertex(uint vid [[vertex_id]]) {
    float2 vert = cornerVerts[vid];
    
    VertOut out;
    out.position = float4(vert, 0, 1);
    out.uv = vert * 0.5 + 0.5;
    
    return out;
}

fragment float4 copyFragment(VertOut in [[stage_in]],
                             texture2d<float> image) {
    float4 color = image.sample(sam, in.uv);
    return color;
}
"""
}

extension MTLCommandBuffer {
    public func copyTexture(pipeline: CopyPipeline, descriptor: MTLRenderPassDescriptor, drawable: MTLDrawable, from texture: MTLTexture) {
        let renderEncoder = makeRenderCommandEncoder(descriptor: descriptor)
        renderEncoder?.setRenderPipelineState(pipeline.pipeline)
        renderEncoder?.setFragmentTexture(texture, index: 0)
        renderEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder?.endEncoding()
    }
}
