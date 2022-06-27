import XCTest
import SwiftUI
@testable import ShaderKit

final class ShaderKitTests: XCTestCase {
    func testLogDefault() throws {
        XCTAssert(Optional<Int>.some(3).logDefault(0, message: "") == 3)
        XCTAssert(Optional<Int>.none.logDefault(0, message: "") == 0)
    }
    
    func testApply() throws {
        var lst = Array(0...10)
        lst.apply { $0.increment() }
        XCTAssert(lst == Array(1...11))
    }
    
    struct Content: View {
        var body: some View {
            Text("E")
        }
    }
}

extension Int {
    fileprivate mutating func increment() {
        self += 1
    }
}
