//
//  TextureProperties.swift
//  
//
//  Created by Noah Pikielny on 6/2/23.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif
import Metal

extension MTLPixelFormat {
    public var channels: Int {
        switch self {
            case .a8Unorm, .r8Unorm, .r8Unorm_srgb, .r8Snorm, .r8Uint, .r8Sint, .r16Unorm, .r16Snorm, .r16Uint, .r16Sint, .r16Float, .r32Uint, .r32Sint, .r32Float:
                return 1
            case .rg8Unorm, .rg8Unorm_srgb, .rg8Snorm, .rg8Uint, .rg8Sint, .rg16Unorm, .rg16Snorm, .rg16Uint, .rg16Sint, .rg16Float, .rg32Uint, .rg32Sint, .rg32Float:
                return 2
            case .b5g6r5Unorm, .a1bgr5Unorm, .rg11b10Float:
                return 3
            case .abgr4Unorm, .bgr5A1Unorm, .rgba8Unorm, .rgba8Unorm_srgb, .rgba8Snorm, .rgba8Uint, .rgba8Sint, .bgra8Unorm, .bgra8Unorm_srgb, .rgb10a2Unorm, .rgb10a2Uint, .bgr10a2Unorm, .rgba16Unorm, .rgba16Snorm, .rgba16Uint, .rgba16Sint, .rgba16Float, .rgba32Uint, .rgba32Sint, .rgba32Float:
                return 4
            default:
                fatalError("Pixel type with unknown channel count")
        }
    }
    
    public static var srgbFormats: [MTLPixelFormat] {
        if #available(macOS 11.0, *) {
            return [.bgra8Unorm_srgb, .r8Unorm_srgb, .rg8Unorm_srgb, .rgba8Unorm_srgb]
        } else {
            return [.bgra8Unorm_srgb, .rgba8Unorm_srgb]
        }
    }
}
