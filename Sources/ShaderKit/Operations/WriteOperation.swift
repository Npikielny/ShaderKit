//
//  WriteOperation.swift
//  
//
//  Created by Noah Pikielny on 10/22/22.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif
import Metal
import UniformTypeIdentifiers

@available(macOS 11.0, *)
public struct WriteOperation: Operation {
    public let texture: Texture
    let blit: BlitPipeline
    let metaData: CGImageMetadata?
    let destination: String
    
    public init(texture: Texture, to destination: String, metaData: CGImageMetadata? = nil) {
        self.texture = texture
        self.blit = BlitPipeline(.synchronizeTexture(texture))
        self.metaData = metaData
        self.destination = destination
    }
    
    func writeImage(device: MTLDevice) {
        let unwrapped = texture.unwrap(device: device)
        let channels = unwrapped.pixelFormat.channels
        
        let pixelBytes = MemoryLayout<UInt8>.stride * channels
        let bytesPerRow = pixelBytes * unwrapped.width
        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: MTLSize(width: unwrapped.width, height: unwrapped.height, depth: 1))
        
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: unwrapped.width * channels * unwrapped.height)
        defer { ptr.deallocate() }
        
        unwrapped.getBytes(ptr, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        
        let colorSpace = (texture.virtualSRGB || MTLPixelFormat.srgbFormats.contains(unwrapped.pixelFormat)) ? CGColorSpace(name: CGColorSpace.sRGB)! : CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        let pixelCount = unwrapped.width * unwrapped.height * channels
        let releaseMaskImagePixelData: CGDataProviderReleaseDataCallback = { (info: UnsafeMutableRawPointer?, data: UnsafeRawPointer, size: Int) -> () in
            return
        }
        let provider = CGDataProvider(dataInfo: nil, data: ptr, size: pixelCount, releaseData: releaseMaskImagePixelData)!
        let bits = MemoryLayout<UInt8>.stride * 8
        let cgImageRef = CGImage(
            width: unwrapped.width,
            height: unwrapped.height,
            bitsPerComponent: bits,
            bitsPerPixel: pixelBytes * 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: CGColorRenderingIntent.defaultIntent
        )!
        
        let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: destination) as CFURL,
            UTType.tiff.identifier as CFString,
            1,
            nil
        )!
        
        if let metaData {
            let writing = CGImageMetadataCreateMutable()
            CGImageMetadataEnumerateTagsUsingBlock(metaData, nil, nil) { key, tag in
                CGImageMetadataSetTagWithPath(writing, nil, key, tag)
                return true
            }
            
            CGImageDestinationAddImage(destination, cgImageRef, [kCGImageDestinationMetadata as String : writing] as CFDictionary)
            CGImageDestinationFinalize(destination)
        } else {
            CGImageDestinationAddImage(destination, cgImageRef, nil)
            CGImageDestinationFinalize(destination)
        }
    }
    
    public func execute(commandQueue: MTLCommandQueue, library: MTLLibrary) async throws {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ShaderError("Unabled to make command buffer with \(commandQueue.device.name)")
        }
        
        blit.encode(commandBuffer: commandBuffer, library: library)
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        writeImage(device: commandQueue.device)
    }
}
