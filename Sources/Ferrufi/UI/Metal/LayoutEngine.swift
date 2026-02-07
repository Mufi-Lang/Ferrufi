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
            
            CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, glyphCount), &positions)
            CTRunGetAdvances(run, CFRangeMake(0, glyphCount), &advances)
            
            for i in 0..<glyphCount {
                glyphPositions.append(GlyphPosition(
                    glyph: glyphs[i],
                    position: positions[i],
                    advance: advances[i].width
                ))
            }
        }
        
        return glyphPositions
    }
}