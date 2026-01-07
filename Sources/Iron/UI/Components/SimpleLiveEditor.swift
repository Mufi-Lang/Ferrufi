//
//  SimpleLiveEditor.swift
//  Iron
//
//  Simplified live markdown editor that avoids complex NSTextView issues
//

import AppKit
import SwiftUI

public struct SimpleLiveEditor: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager

    let placeholder: String
    let onTextChange: (String) -> Void

    public init(
        text: Binding<String>,
        placeholder: String = "Start writing...",
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onTextChange = onTextChange
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = SimpleTextView(frame: .zero, textContainer: nil)

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // Configure text view
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false  // Keep it simple - plain text with live preview
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        // Set initial content
        textView.string = text

        // Apply theme
        updateTheme(textView: textView, theme: themeManager.currentTheme)

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SimpleTextView else { return }

        // Update text if needed
        if textView.string != text {
            textView.string = text
        }

        // Update theme
        updateTheme(textView: textView, theme: themeManager.currentTheme)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateTheme(textView: SimpleTextView, theme: IronTheme) {
        textView.backgroundColor = NSColor(theme.colors.background)
        textView.insertionPointColor = NSColor(theme.colors.accent)
        textView.textColor = NSColor(theme.colors.foreground)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(theme.colors.accent).withAlphaComponent(0.3),
            .foregroundColor: NSColor(theme.colors.foreground),
        ]

        // Update font
        textView.font = NSFont.systemFont(ofSize: 16, weight: .regular)
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        let parent: SimpleLiveEditor

        init(_ parent: SimpleLiveEditor) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? SimpleTextView else { return }

            DispatchQueue.main.async {
                self.parent.text = textView.string
                self.parent.onTextChange(textView.string)
            }
        }

        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            return true
        }
    }
}

// MARK: - Simple NSTextView

class SimpleTextView: NSTextView {

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupEditor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEditor()
    }

    private func setupEditor() {
        // Basic editor setup
        isRichText = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = true
        isAutomaticDashSubstitutionEnabled = true

        // Set up typing attributes
        typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.textColor,
        ]
    }

    // Handle key presses for basic shortcuts
    override func keyDown(with event: NSEvent) {
        // Handle special key combinations
        if event.modifierFlags.contains(.command) {
            switch event.characters {
            case "b":  // Bold
                insertBoldMarkers()
                return
            case "i":  // Italic
                insertItalicMarkers()
                return
            case "`":  // Code
                insertCodeMarkers()
                return
            default:
                break
            }
        }

        // Handle Enter key for list continuation
        if event.keyCode == 36 {  // Enter key
            if handleListContinuation() {
                return
            }
        }

        super.keyDown(with: event)
    }

    private func insertBoldMarkers() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }

        if selectedRange.length > 0 {
            let selectedText = (string as NSString).substring(with: selectedRange)
            let boldText = "**\(selectedText)**"

            if shouldChangeText(in: selectedRange, replacementString: boldText) {
                replaceCharacters(in: selectedRange, with: boldText)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 2, length: selectedText.count)
                )
            }
        } else {
            // Insert markers and position cursor between them
            let markers = "****"
            if shouldChangeText(in: selectedRange, replacementString: markers) {
                replaceCharacters(in: selectedRange, with: markers)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 2, length: 0)
                )
            }
        }
    }

    private func insertItalicMarkers() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }

        if selectedRange.length > 0 {
            let selectedText = (string as NSString).substring(with: selectedRange)
            let italicText = "*\(selectedText)*"

            if shouldChangeText(in: selectedRange, replacementString: italicText) {
                replaceCharacters(in: selectedRange, with: italicText)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 1, length: selectedText.count)
                )
            }
        } else {
            // Insert markers and position cursor between them
            let markers = "**"
            if shouldChangeText(in: selectedRange, replacementString: markers) {
                replaceCharacters(in: selectedRange, with: markers)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 1, length: 0)
                )
            }
        }
    }

    private func insertCodeMarkers() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }

        if selectedRange.length > 0 {
            let selectedText = (string as NSString).substring(with: selectedRange)
            let codeText = "`\(selectedText)`"

            if shouldChangeText(in: selectedRange, replacementString: codeText) {
                replaceCharacters(in: selectedRange, with: codeText)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 1, length: selectedText.count)
                )
            }
        } else {
            // Insert markers and position cursor between them
            let markers = "``"
            if shouldChangeText(in: selectedRange, replacementString: markers) {
                replaceCharacters(in: selectedRange, with: markers)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 1, length: 0)
                )
            }
        }
    }

    private func handleListContinuation() -> Bool {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return false }

        let currentLine = getCurrentLine(at: selectedRange.location)

        // Check for bullet list
        if let match = currentLine.range(of: #"^(\s*)([-*+])\s+"#, options: .regularExpression) {
            let indent = String(currentLine[currentLine.startIndex..<match.upperBound])
            let newLine = "\n\(indent)"

            if shouldChangeText(
                in: NSRange(location: selectedRange.location, length: 0),
                replacementString: newLine
            ) {
                replaceCharacters(
                    in: NSRange(location: selectedRange.location, length: 0), with: newLine)
                return true
            }
        }

        // Check for numbered list
        if currentLine.range(of: #"^(\s*)(\d+)\.\s+"#, options: .regularExpression) != nil {
            let parts = currentLine.components(separatedBy: ". ")
            if let firstPart = parts.first,
                let numberMatch = firstPart.range(of: #"\d+"#, options: .regularExpression),
                let number = Int(String(firstPart[numberMatch]))
            {

                let indent = String(firstPart[firstPart.startIndex..<numberMatch.lowerBound])
                let newLine = "\n\(indent)\(number + 1). "

                if shouldChangeText(
                    in: NSRange(location: selectedRange.location, length: 0),
                    replacementString: newLine
                ) {
                    replaceCharacters(
                        in: NSRange(location: selectedRange.location, length: 0), with: newLine)
                    return true
                }
            }
        }

        return false
    }

    private func getCurrentLine(at location: Int) -> String {
        let text = string as NSString
        let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
        return text.substring(with: lineRange)
    }
}

// MARK: - Live Preview Component

public struct LivePreviewPane: View {
    let markdownText: String
    @EnvironmentObject var themeManager: ThemeManager

    public init(markdownText: String) {
        self.markdownText = markdownText
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(parseMarkdownLines(markdownText), id: \.id) { line in
                    renderLine(line)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(themeManager.currentTheme.colors.background)
    }

    private func renderLine(_ line: MarkdownLine) -> some View {
        Group {
            switch line.type {
            case .header1:
                Text(line.content)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(themeManager.currentTheme.colors.border),
                        alignment: .bottom
                    )

            case .header2:
                Text(line.content)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(themeManager.currentTheme.colors.border),
                        alignment: .bottom
                    )

            case .header3:
                Text(line.content)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .code:
                Text(line.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.colors.backgroundSecondary)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .blockquote:
                Text(line.content)
                    .font(.system(size: 16, design: .serif))
                    .italic()
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .padding(.leading, 16)
                    .overlay(
                        Rectangle()
                            .frame(width: 4)
                            .foregroundColor(themeManager.currentTheme.colors.accent),
                        alignment: .leading
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .listItem:
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                        .font(.system(size: 16, weight: .bold))

                    Text(line.content)
                        .foregroundColor(themeManager.currentTheme.colors.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            case .paragraph:
                Text(renderInlineMarkdown(line.content))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func renderInlineMarkdown(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)

        // Handle bold **text**
        if let range = text.range(of: #"\*\*([^*]+)\*\*"#, options: .regularExpression) {
            let boldText = String(text[range]).replacingOccurrences(of: "*", with: "")
            attributed = AttributedString(
                text.replacingOccurrences(of: String(text[range]), with: boldText))
            if let boldRange = attributed.range(of: boldText) {
                attributed[boldRange].font = .system(size: 16, weight: .bold)
            }
        }

        // Handle italic *text*
        if let range = text.range(of: #"\*([^*]+)\*"#, options: .regularExpression) {
            let italicText = String(text[range]).replacingOccurrences(of: "*", with: "")
            attributed = AttributedString(
                text.replacingOccurrences(of: String(text[range]), with: italicText))
            if let italicRange = attributed.range(of: italicText) {
                attributed[italicRange].font = .system(size: 16).italic()
            }
        }

        // Handle inline code `text`
        if let range = text.range(of: #"`([^`]+)`"#, options: .regularExpression) {
            let codeText = String(text[range]).replacingOccurrences(of: "`", with: "")
            attributed = AttributedString(
                text.replacingOccurrences(of: String(text[range]), with: codeText))
            if let codeRange = attributed.range(of: codeText) {
                attributed[codeRange].font = .system(size: 14, design: .monospaced)
                attributed[codeRange].backgroundColor = NSColor(
                    themeManager.currentTheme.colors.backgroundSecondary)
            }
        }

        return attributed
    }

    private func parseMarkdownLines(_ text: String) -> [MarkdownLine] {
        let lines = text.components(separatedBy: .newlines)
        var result: [MarkdownLine] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                continue
            }

            let markdownLine: MarkdownLine

            if trimmed.hasPrefix("# ") {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .header1,
                    content: String(trimmed.dropFirst(2))
                )
            } else if trimmed.hasPrefix("## ") {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .header2,
                    content: String(trimmed.dropFirst(3))
                )
            } else if trimmed.hasPrefix("### ") {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .header3,
                    content: String(trimmed.dropFirst(4))
                )
            } else if trimmed.hasPrefix("```") {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .code,
                    content: String(trimmed.dropFirst(3))
                )
            } else if trimmed.hasPrefix("> ") {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .blockquote,
                    content: String(trimmed.dropFirst(2))
                )
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .listItem,
                    content: String(trimmed.dropFirst(2))
                )
            } else {
                markdownLine = MarkdownLine(
                    id: index,
                    type: .paragraph,
                    content: trimmed
                )
            }

            result.append(markdownLine)
        }

        return result
    }
}

// MARK: - Supporting Types

struct MarkdownLine {
    let id: Int
    let type: MarkdownLineType
    let content: String
}

enum MarkdownLineType {
    case header1
    case header2
    case header3
    case code
    case blockquote
    case listItem
    case paragraph
}

// MARK: - Preview

struct SimpleLiveEditor_Previews: PreviewProvider {
    @State static var text = """
        # Simple Live Editor

        This is a **simplified** live editor that avoids complex NSTextView formatting issues.

        ## Features

        - Simple and reliable
        - Basic markdown shortcuts
        - Theme-aware colors
        - List continuation

        > This is a blockquote

        ```swift
        func example() {
            print("Simple code block")
        }
        ```
        """

    static var previews: some View {
        HSplitView {
            SimpleLiveEditor(text: $text)
                .environmentObject(ThemeManager())

            LivePreviewPane(markdownText: text)
                .environmentObject(ThemeManager())
        }
        .frame(width: 800, height: 600)
    }
}
