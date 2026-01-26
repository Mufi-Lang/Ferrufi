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

            // Compute the 1-based line number by counting newline separators before charIndex.
            // `components(separatedBy:)` returns 1 element for an empty prefix, so its count is already the correct 1-based line number.
            let nsString = textView.string as NSString
            // Clamp the charIndex into the valid range before slicing
            let safeCharIndex = max(0, min(charIndex, nsString.length))
            let prefix = nsString.substring(with: NSRange(location: 0, length: safeCharIndex))
            let lineNumber = prefix.components(separatedBy: "\n").count

            // Vertical position: convert text container coordinates to ruler coordinates so wrapped fragments align visually.
            // We convert a point at the fragment's minY from the text view coordinate space into the ruler's coordinate space.
            let containerOrigin = textView.textContainerOrigin
            let yInTextView = containerOrigin.y + lineRect.minY
            // Convert the point from the textView coordinate system into this ruler's coordinate system.
            let pointInRuler = textView.convert(NSPoint(x: 0, y: yInTextView), to: self)
            let y = pointInRuler.y

            let text = NSString(string: "\(lineNumber)")
            let size = text.size(withAttributes: attrs)
            let x = max(6, self.ruleThickness - size.width - 6)  // leave small left padding

            // Draw the number vertically centered in the fragment rectangle as converted into ruler coordinates.
            let drawPoint = NSPoint(x: x, y: y + (lineRect.height - size.height) / 2.0)
            text.draw(at: drawPoint, withAttributes: attrs)

            glyphIndex = NSMaxRange(lineGlyphRange)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
