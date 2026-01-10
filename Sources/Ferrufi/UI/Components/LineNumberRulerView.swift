//
//  LineNumberRulerView.swift
//  Ferrufi
//
//  Created by a on 2026-01-09.
//

import AppKit
import Foundation
import SwiftUI

// Adds a compact vertical ruler that displays line numbers adjacent to the text view.
// This is a lightweight implementation intended for quick visibility of line numbers.
// It draws the line number for each visible line and updates when the text view scrolls.
final class LineNumberRulerView: NSRulerView {

    weak var textView: NSTextView?

    init(textView: NSTextView) {
        // Ensure we have a scrollView to attach to (the textView should be embedded in one)
        let scrollView = textView.enclosingScrollView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        self.textView = textView
        self.clientView = textView
        self.ruleThickness = 44.0

        // Redraw when scrolling changes the visible rectangle
        if let contentView = scrollView?.contentView {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(contentViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: contentView
            )
        }
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc private func contentViewDidScroll(_ notification: Notification) {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer,
            let clipView = textView.enclosingScrollView?.contentView
        else { return }

        // The visible rectangle in text container coordinates
        let visibleRect = clipView.bounds
        let origin = textView.textContainerOrigin
        let adjustedRect = visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)

        // Glyph range in the visible rect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: adjustedRect, in: textContainer)
        guard glyphRange.length > 0 else { return }

        // Attributes for line numbers
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        // Iterate glyphs and draw line numbers for line fragments
        var glyphIndex = glyphRange.location
        let endGlyph = NSMaxRange(glyphRange)

        while glyphIndex < endGlyph {
            var lineGlyphRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange,
                withoutAdditionalLayout: true)

            // Determine the character index for the start of the line
            let charIndex = layoutManager.characterIndexForGlyph(at: lineGlyphRange.location)

            // Line number is number of newline separators before charIndex + 1
            let prefix = (textView.string as NSString).substring(
                with: NSRange(location: 0, length: charIndex))
            let lineNumber = prefix.components(separatedBy: "\n").count + 1

            // Vertical position, adjusted by text container origin and visible clip origin
            let y = lineRect.minY + origin.y - (clipView.bounds.minY)

            let text = NSString(string: "\(lineNumber)")
            let size = text.size(withAttributes: attrs)
            let x = max(6, self.ruleThickness - size.width - 6)  // leave small left padding

            let drawPoint = NSPoint(x: x, y: y + (lineRect.height - size.height) / 2.0)
            text.draw(at: drawPoint, withAttributes: attrs)

            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
