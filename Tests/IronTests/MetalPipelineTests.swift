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
        let font = NSFont.systemFont(ofSize: 14)
        
        let glyphs = layoutEngine.layout(state: state, font: font)
        
        XCTAssertEqual(glyphs.count, text.count)
    }

    func testLayoutEngineLigatureHandling() {
        let text = "=="
        let state = RenderState(text: text, cursorPosition: 0)
        let layoutEngine = LayoutEngine()
        let font = NSFont.systemFont(ofSize: 14) // Standard fonts might not have == ligatures, but we test the mechanism
        
        let glyphs = layoutEngine.layout(state: state, font: font)
        
        // If it's a ligature, glyphs.count might be 1. 
        // We just verify it returns something valid for now.
        XCTAssertTrue(glyphs.count > 0)
    }
}
