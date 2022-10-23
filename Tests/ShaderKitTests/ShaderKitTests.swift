import XCTest
import SwiftUI
@testable import ShaderKit

final class ShaderKitTests: XCTestCase {
    struct FakeShader: SKShader {
        func encode(commandBuffer: MTLCommandBuffer) {
            
        }
        
    }
    
    func testCommandBufferCompilation() {
        let commandBuffer = CommandOperation {
            for _ in 0...3 {
                FakeShader()
            }
            FakeShader()
        }
    }
    
}
