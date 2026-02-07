import Foundation
import CoreGraphics
import CoreText
import AppKit

/// Responsible for calculating the layout and positioning of glyphs using CoreText.
public class LayoutEngine {
    
    public struct GlyphPosition {
        public let glyph: CGGlyph
        public let position: CGPoint
        public let advance: CGFloat
        public let tokenType: Int
    }
    
    public init() {}
    
    /// Calculates glyph positions for the given render state using CoreText for ligatures and layout.
    public func layout(state: RenderState, font: NSFont) -> [GlyphPosition] {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let attrString = NSAttributedString(string: state.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        
        var glyphPositions: [GlyphPosition] = []
        let runs = CTLineGetGlyphRuns(line) as? [CTRun] ?? []
        
        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            
            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            var advances = [CGSize](repeating: .zero, count: glyphCount)
            var indices = [CFIndex](repeating: 0, count: glyphCount)
            
            CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
            CTRunGetAdvances(run, CFRangeMake(0, glyphCount), &advances)
            CTRunGetStringIndices(run, CFRangeMake(0, glyphCount), &indices)

            for i in 0..<glyphCount {
                let stringIndex = indices[i]
                let tokenType = state.tokenTypes?[safe: Int(stringIndex)] ?? 0
                
                glyphPositions.append(GlyphPosition(
                    glyph: glyphs[i],
                    position: positions[i],
                    advance: advances[i].width,
                    tokenType: tokenType
                ))
            }
        }
        
        return glyphPositions
    }
    
    /// Returns the rect for a specific character index.
    public func rect(for index: Int, state: RenderState, font: NSFont) -> CGRect {
        let glyphPositions = layout(state: state, font: font)
        
        // Find the glyph at or near the index
        if index < glyphPositions.count {
            let gp = glyphPositions[index]
            return CGRect(x: gp.position.x, y: gp.position.y, width: 2, height: font.pointSize)
        } else if let last = glyphPositions.last {
            return CGRect(x: last.position.x + last.advance, y: last.position.y, width: 2, height: font.pointSize)
        }
        
        return CGRect(x: 0, y: 0, width: 2, height: font.pointSize)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}