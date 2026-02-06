import XCTest
import SwiftUI
@testable import Ferrufi

final class MetalPipelineTests: XCTestCase {
    
    func testRenderStateInitialization() {
        let text = "Hello, Mufi!"
        let cursorPosition = 5
        let state = RenderState(text: text, cursorPosition: cursorPosition)
        
        XCTAssertEqual(state.text, text)
        XCTAssertEqual(state.cursorPosition, cursorPosition)
    }
    
    func testLayoutEngineGlyphCalculation() {
        let text = "ABC"
        let state = RenderState(text: text, cursorPosition: 0)
        let layoutEngine = LayoutEngine()
        
        // Mock or simple layout calculation
        let glyphs = layoutEngine.layout(state: state)
        
        XCTAssertEqual(glyphs.count, text.count)
    }
}
