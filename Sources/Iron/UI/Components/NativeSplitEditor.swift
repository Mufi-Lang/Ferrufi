//
//  NativeSplitEditor.swift
//  Iron
//
//  Native SwiftUI split preview markdown editor without HTML
//

import SwiftUI

public struct NativeSplitEditor: View {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager

    let placeholder: String
    let onTextChange: (String) -> Void

    @State private var isPreviewVisible = true
    @State private var splitRatio: CGFloat = 0.5
    @State private var isDraggingSplitter = false

    public init(
        text: Binding<String>,
        placeholder: String = "Start writing...",
        onTextChange: @escaping (String) -> Void = { _ in }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onTextChange = onTextChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            editorToolbar

            // Split view
            HStack(spacing: 0) {
                // Left: Raw markdown editor
                PlainTextEditor(
                    text: $text,
                    placeholder: placeholder,
                    onTextChange: onTextChange
                )
                .environmentObject(themeManager)
                .frame(maxWidth: .infinity)

                if isPreviewVisible {
                    // Splitter
                    Rectangle()
                        .fill(themeManager.currentTheme.colors.accent.opacity(0.3))
                        .frame(width: 2)

                        .onHover { hovering in
                            if hovering {
                                NSCursor.resizeLeftRight.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    isDraggingSplitter = true
                                    // Simple split ratio update
                                    splitRatio = max(0.2, min(0.8, splitRatio))
                                }
                                .onEnded { _ in
                                    isDraggingSplitter = false
                                }
                        )

                    // Right: Native preview
                    NativeMarkdownPreview(markdown: text)
                        .environmentObject(themeManager)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .background(themeManager.currentTheme.colors.background)
    }

    private var editorToolbar: some View {
        HStack(spacing: 6) {
            // Preview toggle
            Button(action: { isPreviewVisible.toggle() }) {
                Image(systemName: isPreviewVisible ? "sidebar.right" : "doc.text")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(isPreviewVisible ? "Hide Preview" : "Show Preview")

            Divider()
                .frame(height: 16)

            // Essential formatting buttons - compact icons only
            NativeFormatButton(icon: "bold", tooltip: "Bold") {
                insertWrapping(prefix: "**", suffix: "**")
            }

            NativeFormatButton(icon: "italic", tooltip: "Italic") {
                insertWrapping(prefix: "*", suffix: "*")
            }

            NativeFormatButton(icon: "code", tooltip: "Inline Code") {
                insertWrapping(prefix: "`", suffix: "`")
            }

            NativeFormatButton(icon: "number", tooltip: "Header") {
                insertAtLineStart("# ")
            }

            NativeFormatButton(icon: "list.bullet", tooltip: "List") {
                insertAtLineStart("- ")
            }

            NativeFormatButton(icon: "curlybraces", tooltip: "Code Block") {
                insertText("\n```\n\n```\n")
            }

            Spacer()

            // Minimal word count
            if !text.isEmpty {
                Text("\(wordCount(text)) words")
                    .font(.system(size: 11))
                    .foregroundColor(themeManager.currentTheme.colors.foregroundTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.3))
    }

    private func insertWrapping(prefix: String, suffix: String) {
        let newText = text + prefix + suffix
        text = newText
        onTextChange(newText)
    }

    private func insertAtLineStart(_ prefix: String) {
        let newText = text + "\n" + prefix
        text = newText
        onTextChange(newText)
    }

    private func insertText(_ newText: String) {
        text = text + newText
        onTextChange(text)
    }

    private func wordCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
}

// MARK: - Plain Text Editor

struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager

    let placeholder: String
    let onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        // Configure text view
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Apply theme
        updateTheme(textView: textView)

        // Set initial text
        textView.string = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let cursorPos = textView.selectedRange().location
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(cursorPos, text.count), length: 0))
        }

        updateTheme(textView: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateTheme(textView: NSTextView) {
        textView.backgroundColor = NSColor(themeManager.currentTheme.colors.background)
        textView.textColor = NSColor(themeManager.currentTheme.colors.foreground)
        textView.insertionPointColor = NSColor(themeManager.currentTheme.colors.accent)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(themeManager.currentTheme.colors.accent).withAlphaComponent(
                0.3)
        ]
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        let parent: PlainTextEditor

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            DispatchQueue.main.async {
                self.parent.text = textView.string
                self.parent.onTextChange(textView.string)
            }
        }
    }
}

// MARK: - Native Markdown Preview

struct NativeMarkdownPreview: View {
    let markdown: String
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(parseMarkdown(markdown), id: \.id) { element in
                    renderElement(element)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(themeManager.currentTheme.colors.background)
    }

    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeBlockContent: [String] = []
        var codeBlockLanguage: String?

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    elements.append(
                        MarkdownElement(
                            id: UUID(),
                            type: .codeBlock(language: codeBlockLanguage),
                            content: codeBlockContent.joined(separator: "\n")
                        ))
                    inCodeBlock = false
                    codeBlockContent = []
                    codeBlockLanguage = nil
                } else {
                    // Start code block
                    inCodeBlock = true
                    let language = String(
                        line.dropFirst(3).trimmingCharacters(in: .whitespacesAndNewlines))
                    codeBlockLanguage = language.isEmpty ? nil : language
                }
                continue
            }

            if inCodeBlock {
                codeBlockContent.append(line)
                continue
            }

            if line.isEmpty {
                continue
            }

            // Parse different markdown elements
            if line.hasPrefix("#") {
                let level = line.prefix { $0 == "#" }.count
                let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                elements.append(
                    MarkdownElement(
                        id: UUID(),
                        type: .header(level: level),
                        content: content
                    ))
            } else if line.hasPrefix("> ") {
                let content = String(line.dropFirst(2))
                elements.append(
                    MarkdownElement(
                        id: UUID(),
                        type: .quote,
                        content: content
                    ))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let content = String(line.dropFirst(2))
                elements.append(
                    MarkdownElement(
                        id: UUID(),
                        type: .listItem,
                        content: content
                    ))
            } else {
                elements.append(
                    MarkdownElement(
                        id: UUID(),
                        type: .paragraph,
                        content: line
                    ))
            }
        }

        return elements
    }

    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element.type {
        case .header(let level):
            let fontSize: CGFloat = max(32 - CGFloat(level - 1) * 4, 16)
            renderFormattedText(element.content)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(themeManager.currentTheme.colors.accent)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph:
            renderFormattedText(element.content)
                .font(.body)
                .foregroundColor(themeManager.currentTheme.colors.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .quote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(themeManager.currentTheme.colors.accent)
                    .frame(width: 4)
                renderFormattedText(element.content)
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
                    .italic()
                Spacer()
            }
            .padding(.leading, 16)

        case .listItem:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(themeManager.currentTheme.colors.accent)
                renderFormattedText(element.content)
                    .font(.body)
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                Spacer()
            }
            .padding(.leading, 16)

        case .codeBlock(let language):
            VStack(alignment: .leading, spacing: 0) {
                if let lang = language, !lang.isEmpty {
                    HStack {
                        Text(lang.uppercased())
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.colors.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeManager.currentTheme.colors.backgroundSecondary)
                }

                Text(element.content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.colors.foreground)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.currentTheme.colors.backgroundSecondary.opacity(0.7))
            }
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func renderFormattedText(_ text: String) -> some View {
        let parts = parseInlineFormatting(text)

        if parts.count == 1 && parts[0].type == .plain {
            Text(parts[0].content)
        } else {
            parts.reduce(Text("")) { result, part in
                switch part.type {
                case .plain:
                    result + Text(part.content)
                case .bold:
                    result + Text(part.content).bold()
                case .italic:
                    result + Text(part.content).italic()
                case .code:
                    result
                        + Text(part.content)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(themeManager.currentTheme.colors.accent)
                }
            }
        }
    }

    private func parseInlineFormatting(_ text: String) -> [FormattedTextPart] {
        var parts: [FormattedTextPart] = []
        let _ = text  // Remove unused variable warning

        // Simple regex patterns for inline formatting
        let patterns: [(String, FormattedTextType)] = [
            (#"\*\*([^*]+)\*\*"#, .bold),
            (#"\*([^*]+)\*"#, .italic),
            (#"`([^`]+)`"#, .code),
        ]

        var processedRanges: [NSRange] = []

        for (pattern, type) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(0..<text.count))

            for match in matches {
                let fullRange = match.range
                let contentRange = match.range(at: 1)

                // Check if this range overlaps with already processed ranges
                let overlaps = processedRanges.contains { existing in
                    NSLocationInRange(fullRange.location, existing)
                        || NSLocationInRange(existing.location, fullRange)
                }

                if !overlaps, let contentSwiftRange = Range(contentRange, in: text) {
                    let content = String(text[contentSwiftRange])
                    parts.append(FormattedTextPart(content: content, type: type, range: fullRange))
                    processedRanges.append(fullRange)
                }
            }
        }

        // Sort by location and fill in plain text parts
        parts.sort { $0.range.location < $1.range.location }

        var result: [FormattedTextPart] = []
        var lastLocation = 0

        for part in parts {
            // Add plain text before this formatted part
            if part.range.location > lastLocation {
                let plainRange = NSRange(
                    location: lastLocation, length: part.range.location - lastLocation)
                if let plainSwiftRange = Range(plainRange, in: text) {
                    let plainText = String(text[plainSwiftRange])
                    if !plainText.isEmpty {
                        result.append(
                            FormattedTextPart(content: plainText, type: .plain, range: plainRange))
                    }
                }
            }

            result.append(part)
            lastLocation = part.range.location + part.range.length
        }

        // Add remaining plain text
        if lastLocation < text.count {
            let remainingRange = NSRange(location: lastLocation, length: text.count - lastLocation)
            if let remainingSwiftRange = Range(remainingRange, in: text) {
                let remainingText = String(text[remainingSwiftRange])
                if !remainingText.isEmpty {
                    result.append(
                        FormattedTextPart(
                            content: remainingText, type: .plain, range: remainingRange))
                }
            }
        }

        // If no formatting found, return the whole text as plain
        if result.isEmpty {
            result.append(
                FormattedTextPart(content: text, type: .plain, range: NSRange(0..<text.count)))
        }

        return result
    }
}

// MARK: - Supporting Types

struct MarkdownElement {
    let id: UUID
    let type: MarkdownElementType
    let content: String
}

enum MarkdownElementType {
    case header(level: Int)
    case paragraph
    case quote
    case listItem
    case codeBlock(language: String?)
}

struct FormattedTextPart {
    let content: String
    let type: FormattedTextType
    let range: NSRange
}

enum FormattedTextType {
    case plain
    case bold
    case italic
    case code
}

struct ViewWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Reusable Components

struct NativeFormatButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
        }
        .buttonStyle(ToolbarButtonStyle(themeManager: themeManager))
        .help(tooltip)
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    let themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(themeManager.currentTheme.colors.foregroundSecondary)
            .font(.system(size: 11))
            .padding(4)
            .background(
                configuration.isPressed
                    ? themeManager.currentTheme.colors.accent.opacity(0.2)
                    : Color.clear
            )
            .cornerRadius(4)
    }
}

// MARK: - Preview

struct NativeSplitEditor_Previews: PreviewProvider {
    @State static var text = """
        # Native Split Editor

        This is a **native SwiftUI** markdown editor with *live preview*.

        ## Features

        - No HTML rendering
        - Native SwiftUI components
        - Live preview
        - Syntax highlighting

        Here's some `inline code` and a code block:

        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```

        > This is a quote block

        More text here.
        """

    static var previews: some View {
        NativeSplitEditor(text: $text)
            .environmentObject(ThemeManager())
            .frame(width: 800, height: 600)
    }
}
