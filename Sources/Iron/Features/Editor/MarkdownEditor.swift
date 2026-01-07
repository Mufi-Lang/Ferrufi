//
//  MarkdownEditor.swift
//  Iron
//
//  Created on 2024-12-19.
//

import AppKit
import Foundation
import SwiftUI

/// A markdown-aware text editor built on NSTextView with syntax highlighting and enhanced editing features
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool

    var onTextChange: ((String) -> Void)?
    var onSave: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = MarkdownTextView(frame: .zero, textContainer: nil)

        // Configure text view
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 16, height: 16)

        // Configure text container
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Store references
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Update text if it changed externally
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text

            // Only apply syntax highlighting if textStorage is available
            if textView.textStorage != nil {
                context.coordinator.applyMarkdownSyntaxHighlighting()
            }

            // Restore selection if possible
            let newRange = NSRange(location: min(selectedRange.location, text.count), length: 0)
            textView.setSelectedRange(newRange)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var textView: MarkdownTextView?
        weak var scrollView: NSScrollView?

        private var syntaxHighlighter: MarkdownSyntaxHighlighter

        init(_ parent: MarkdownEditor) {
            self.parent = parent
            self.syntaxHighlighter = MarkdownSyntaxHighlighter()
            super.init()
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }

            let newText = textView.string
            if newText != parent.text {
                parent.text = newText
                parent.onTextChange?(newText)

                // Apply syntax highlighting with a slight delay to avoid performance issues
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.applyMarkdownSyntaxHighlighting()
                }
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isEditing = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isEditing = false
            parent.onSave?()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                return handleNewline(textView)
            case #selector(NSResponder.insertTab(_:)):
                return handleTab(textView)
            case #selector(NSResponder.deleteBackward(_:)):
                return handleBackspace(textView)
            default:
                return false
            }
        }

        // MARK: - Markdown-specific editing behaviors

        @MainActor
        private func handleNewline(_ textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()
            let text = textView.string

            // Find the current line
            let lineRange = (text as NSString).lineRange(for: selectedRange)
            let currentLine = (text as NSString).substring(with: lineRange)

            // Handle list continuation
            if let listMatch = currentLine.range(
                of: #"^(\s*)([-*+]|\d+\.)\s"#, options: .regularExpression)
            {
                let prefix = String(currentLine[currentLine.startIndex..<listMatch.upperBound])
                textView.insertText(
                    "\n\(prefix)", replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }

            // Handle blockquote continuation
            if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                let spaces = String(currentLine.prefix(while: { $0.isWhitespace }))
                textView.insertText(
                    "\n\(spaces)> ", replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            }

            return false
        }

        @MainActor
        private func handleTab(_ textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()

            if selectedRange.length == 0 {
                // Insert 2 spaces instead of tab for consistency
                textView.insertText(
                    "  ", replacementRange: NSRange(location: NSNotFound, length: 0))
                return true
            } else {
                // Indent selected lines
                indentSelectedLines(textView, indent: true)
                return true
            }
        }

        @MainActor
        private func handleBackspace(_ textView: NSTextView) -> Bool {
            let selectedRange = textView.selectedRange()
            let text = textView.string

            if selectedRange.length == 0 && selectedRange.location > 0 {
                // Smart unindentation
                let lineRange = (text as NSString).lineRange(for: selectedRange)
                let currentLine = (text as NSString).substring(with: lineRange)

                if currentLine.hasPrefix("  ") && selectedRange.location == lineRange.location + 2 {
                    textView.setSelectedRange(NSRange(location: lineRange.location, length: 2))
                    textView.insertText(
                        "", replacementRange: NSRange(location: lineRange.location, length: 2))
                    return true
                }
            }

            return false
        }

        @MainActor
        private func indentSelectedLines(_ textView: NSTextView, indent: Bool) {
            let selectedRange = textView.selectedRange()
            let text = textView.string as NSString
            let linesRange = text.lineRange(for: selectedRange)

            var newText = ""
            var newSelectedRange = selectedRange

            text.enumerateSubstrings(in: linesRange, options: [.byLines, .substringNotRequired]) {
                _, lineRange, _, _ in
                let line = text.substring(with: lineRange)
                if indent {
                    newText += "  \(line)"
                } else {
                    if line.hasPrefix("  ") {
                        newText += String(line.dropFirst(2))
                    } else {
                        newText += line
                    }
                }
            }

            textView.setSelectedRange(linesRange)
            textView.insertText(newText, replacementRange: linesRange)

            // Adjust selection
            if indent {
                newSelectedRange.location += 2
            } else {
                newSelectedRange.location = max(0, newSelectedRange.location - 2)
            }
            textView.setSelectedRange(newSelectedRange)
        }

        // MARK: - Syntax Highlighting

        @MainActor
        func applyMarkdownSyntaxHighlighting() {
            guard let textView = textView else { return }
            let text = textView.string
            let range = NSRange(location: 0, length: text.count)

            // Clear existing attributes
            // Reset attributes only if textStorage exists
            guard let textStorage = textView.textStorage else {
                print("Warning: textView.textStorage is nil, skipping attribute reset")
                return
            }

            textStorage.removeAttribute(.foregroundColor, range: range)
            textStorage.removeAttribute(.font, range: range)
            textStorage.removeAttribute(.backgroundColor, range: range)

            // Apply base font
            let baseFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textStorage.addAttribute(.font, value: baseFont, range: range)
            textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)

            // Apply markdown syntax highlighting
            syntaxHighlighter.highlight(textStorage: textStorage, in: range)
        }
    }
}

/// Custom NSTextView subclass for additional markdown-specific functionality
class MarkdownTextView: NSTextView {

    override func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            setupMarkdownFeatures()
        }
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        Task { @MainActor in
            setupMarkdownFeatures()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Task { @MainActor in
            setupMarkdownFeatures()
        }
    }

    @MainActor
    private func setupMarkdownFeatures() {
        // Enable smart quotes and dashes
        isAutomaticQuoteSubstitutionEnabled = true
        isAutomaticDashSubstitutionEnabled = true

        // Configure spell checking
        isContinuousSpellCheckingEnabled = true
        isGrammarCheckingEnabled = true

        // Configure appearance
        backgroundColor = NSColor.textBackgroundColor
        insertionPointColor = NSColor.controlAccentColor

        // Set up font
        font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }

    // MARK: - Keyboard shortcuts for markdown formatting

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "b":
                toggleBold()
                return
            case "i":
                toggleItalic()
                return
            case "k":
                insertLink()
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }

    @MainActor
    private func toggleBold() {
        wrapSelectedText(prefix: "**", suffix: "**", placeholder: "bold text")
    }

    @MainActor
    private func toggleItalic() {
        wrapSelectedText(prefix: "*", suffix: "*", placeholder: "italic text")
    }

    @MainActor
    private func insertLink() {
        wrapSelectedText(prefix: "[", suffix: "](url)", placeholder: "link text")
    }

    @MainActor
    private func wrapSelectedText(prefix: String, suffix: String, placeholder: String) {
        let selectedRange = self.selectedRange()
        let selectedText = (string as NSString).substring(with: selectedRange)

        let newText: String
        if selectedText.isEmpty {
            newText = "\(prefix)\(placeholder)\(suffix)"
        } else {
            newText = "\(prefix)\(selectedText)\(suffix)"
        }

        insertText(newText, replacementRange: selectedRange)

        // Select the placeholder or wrapped text
        if selectedText.isEmpty {
            let newRange = NSRange(
                location: selectedRange.location + prefix.count, length: placeholder.count)
            setSelectedRange(newRange)
        }
    }
}
