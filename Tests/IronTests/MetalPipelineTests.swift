import XCTest
import SwiftUI
@testable import Ferrufi

final class MetalPipelineTests: XCTestCase {
    
    func testRenderStateWithTokenTypes() {
        let text = "Mufi"
        let tokenTypes = [1, 1, 1, 1] // All glow
        let state = RenderState(text: text, cursorPosition: 0, tokenTypes: tokenTypes)
        
        XCTAssertEqual(state.tokenTypes, tokenTypes)
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

    func testCursorRectCalculation() {
        let text = "Hello"
        let state = RenderState(text: text, cursorPosition: 2)
        let layoutEngine = LayoutEngine()
        let font = NSFont.systemFont(ofSize: 14)
        
        let rect = layoutEngine.rect(for: 2, state: state, font: font)
        
        XCTAssertTrue(rect.origin.x > 0)
        XCTAssertEqual(rect.size.height, font.pointSize)
    }
}
