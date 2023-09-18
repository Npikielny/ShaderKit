//
//  File.swift
//  
//
//  Created by Noah Pikielny on 7/15/22.
//

import Foundation
import Metal

public struct BlitPipeline: SKShader {
    public enum Representation {
        case direct((_ encoder: MTLBlitCommandEncoder) -> ())
        case copy(_ from: Texture, _ to: Texture)
        case copyBuffer(
            _ source: MTLBuffer,
            _ sourceOffset: Int = 0,
            _ destination: MTLBuffer,
            _ destinationOffseet: Int = 0,
            _ size: Int
        )
        case partialCopy(
            _ source: Texture,
            _ sourceMipMapLevel: Int = 0,
            _ sourceCenter: MTLOrigin? = nil,
            _ size: MTLSize,
            _ destination: Texture,
            _ destinationMipMapLevel: Int = 0,
            _ desinationCenter: MTLOrigin? = nil
        )
        case synchronizeTexture(Texture)
    }
    
    let representation: Representation
    public init(_ representation: Representation) {
        self.representation = representation
    }
    
    public func encode(commandBuffer: MTLCommandBuffer, library: MTLLibrary) {
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            fatalError("Unable to make blit command encoder")
        }
        let device = commandBuffer.device
        switch representation {
            case let .synchronizeTexture(texture):
#if os(iOS)
                return
#else
                let unwrapped = texture.unwrap(device: device)
                if unwrapped.storageMode == .private { return }
                encoder.synchronize(resource: unwrapped)
#endif
            case let .direct(closure):
                closure(encoder)
            case let .copy(from, to):
                encoder.copy(
                    from: from.construct().unwrap(device: device),
                    to: to.construct().unwrap(device: device)
                )
            case let .copyBuffer(source, sourceOffset, destination, destinationOffset, size):
                encoder.copy(
                    from: source,
                    sourceOffset: sourceOffset,
                    to: destination,
                    destinationOffset: destinationOffset,
                    size: size
                )
            case let .partialCopy(source, sourceMipMap, sourceOrigin, size, destination, destinationMipMap, destinationOrigin):
                
                let source = source.unwrap(device: device)
                let destination = destination.unwrap(device: device)
                
                if let sourceOrigin = sourceOrigin, let destinationOrigin = destinationOrigin {
                    encoder.copy(
                        from: source,
                        sourceSlice: 0,
                        sourceLevel: sourceMipMap,
                        sourceOrigin: sourceOrigin,
                        sourceSize: size,
                        to: destination,
                        destinationSlice: 0,
                        destinationLevel: destinationMipMap,
                        destinationOrigin: destinationOrigin
                    )
                } else {
                    encoder.copy(
                        from: source,
                        sourceSlice: 0,
                        sourceLevel: sourceMipMap,
                        to: destination,
                        destinationSlice: 0,
                        destinationLevel: destinationMipMap,
                        sliceCount: 1,
                        levelCount: 1
                    )
                }
        }
        encoder.endEncoding()
    }
}
