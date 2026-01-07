//
//  NotionStyleEditor.swift
//  Iron
//
//  Notion-style live markdown editor with async rendering and proper code block support
//

import AppKit
import SwiftUI

public struct NotionStyleEditor: NSViewRepresentable {
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
        let textContainer = NSTextContainer()
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage()

        // Set up text system
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = NotionTextView(frame: .zero, textContainer: textContainer)
        textView.coordinator = context.coordinator

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
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)

        // Set initial content and theme
        textView.string = text
        textView.themeManager = themeManager

        // Start async rendering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            textView.scheduleAsyncRender()
        }

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NotionTextView else { return }

        // Update text if changed externally (preserve cursor)
        if textView.string != text {
            let cursorPos = textView.selectedRange().location
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(cursorPos, text.count), length: 0))
            textView.scheduleAsyncRender()
        }

        // Update theme
        textView.themeManager = themeManager
        textView.updateThemeColors()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        let parent: NotionStyleEditor
        private var lastTextChangeTime = Date()

        init(_ parent: NotionStyleEditor) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NotionTextView else {
                return
            }

            lastTextChangeTime = Date()

            // Update binding immediately
            DispatchQueue.main.async {
                self.parent.text = textView.string
                self.parent.onTextChange(textView.string)
            }

            // Schedule async rendering with longer debouncing for stability
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if Date().timeIntervalSince(self.lastTextChangeTime) >= 0.25 {
                    textView.scheduleAsyncRender()
                }
            }
        }
    }
}

// MARK: - Custom NSTextView with Async Rendering

class NotionTextView: NSTextView {
    var themeManager: ThemeManager?
    var coordinator: NotionStyleEditor.Coordinator?
    private var renderingQueue = DispatchQueue(label: "notion.rendering", qos: .userInteractive)
    private var isRendering = false
    private var pendingRender = false

    override func awakeFromNib() {
        super.awakeFromNib()
        Task { @MainActor in
            setupNotionStyle()
        }
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        Task { @MainActor in
            setupNotionStyle()
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Task { @MainActor in
            setupNotionStyle()
        }
    }

    private func setupNotionStyle() {
        // Enable rich text features
        isRichText = true
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticTextReplacementEnabled = false

        // Set up typing attributes
        typingAttributes = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.textColor,
        ]

        // Trigger initial render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.scheduleAsyncRender()
        }
    }

    func updateThemeColors() {
        guard let theme = themeManager?.currentTheme else { return }

        backgroundColor = NSColor(theme.colors.background)
        insertionPointColor = NSColor(theme.colors.accent)
        selectedTextAttributes = [
            .backgroundColor: NSColor(theme.colors.accent).withAlphaComponent(0.3),
            .foregroundColor: NSColor(theme.colors.foreground),
        ]
    }

    func scheduleAsyncRender() {
        guard !isRendering else {
            pendingRender = true
            return
        }

        isRendering = true
        let currentText = string
        let cursorPos = selectedRange().location

        // Debounce rapid changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard !self.isRendering else { return }

            self.isRendering = true

            Task { @MainActor in
                // Process markdown on main thread to avoid actor issues
                let renderingData = self.processMarkdownForRendering(currentText)

                self.applyRenderingData(renderingData, preservingCursorAt: cursorPos)
                self.isRendering = false

                // Check if another render was requested
                if self.pendingRender {
                    self.pendingRender = false
                    self.scheduleAsyncRender()
                }
            }
        }
    }

    private func processMarkdownForRendering(_ text: String) -> RenderingData {
        var renderingData = RenderingData()

        // Process headers
        renderingData.headers = findHeaderRanges(in: text)

        // Process bold/italic
        renderingData.boldRanges = findBoldRanges(in: text)
        renderingData.italicRanges = findItalicRanges(in: text)

        // Process code
        renderingData.inlineCodeRanges = findInlineCodeRanges(in: text)
        renderingData.codeBlockRanges = findCodeBlockRanges(in: text)

        // Process links
        renderingData.linkRanges = findLinkRanges(in: text)

        // Process lists
        renderingData.listRanges = findListRanges(in: text)

        // Process blockquotes
        renderingData.quoteRanges = findQuoteRanges(in: text)

        return renderingData
    }

    private func applyRenderingData(_ data: RenderingData, preservingCursorAt cursorPos: Int) {
        guard let textStorage = self.textStorage else {
            return
        }
        guard let theme = themeManager?.currentTheme else {
            return
        }

        // Clear all formatting
        let fullRange = NSRange(0..<textStorage.length)
        textStorage.removeAttribute(.font, range: fullRange)
        textStorage.removeAttribute(.foregroundColor, range: fullRange)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        textStorage.removeAttribute(.underlineStyle, range: fullRange)

        // Apply base formatting
        let baseFont = NSFont.systemFont(ofSize: 16)
        let baseColor = NSColor(theme.colors.foreground)
        textStorage.addAttribute(.font, value: baseFont, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: baseColor, range: fullRange)

        // Apply all formatting
        applyHeaders(data.headers, to: textStorage, theme: theme)
        applyBold(data.boldRanges, to: textStorage, theme: theme)
        applyItalic(data.italicRanges, to: textStorage, theme: theme)
        applyInlineCode(data.inlineCodeRanges, to: textStorage, theme: theme)
        applyCodeBlocks(data.codeBlockRanges, to: textStorage, theme: theme)
        applyLinks(data.linkRanges, to: textStorage, theme: theme)
        applyLists(data.listRanges, to: textStorage, theme: theme)
        applyQuotes(data.quoteRanges, to: textStorage, theme: theme)

        // Restore cursor position
        let safeCursorPos = min(cursorPos, textStorage.length)
        setSelectedRange(NSRange(location: safeCursorPos, length: 0))
    }

    // MARK: - Range Finding Methods

    private func findHeaderRanges(in text: String) -> [HeaderRange] {
        var headers: [HeaderRange] = []
        let patterns = [
            ("^(#{1})\\s+(.+)$", 1),
            ("^(#{2})\\s+(.+)$", 2),
            ("^(#{3})\\s+(.+)$", 3),
            ("^(#{4})\\s+(.+)$", 4),
            ("^(#{5})\\s+(.+)$", 5),
            ("^(#{6})\\s+(.+)$", 6),
        ]

        for (pattern, level) in patterns {
            guard
                let regex = try? NSRegularExpression(
                    pattern: pattern, options: [.anchorsMatchLines])
            else { continue }
            let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

            for match in matches {
                let syntaxRange = match.range(at: 1)
                let contentRange = match.range(at: 2)

                if syntaxRange.location != NSNotFound && contentRange.location != NSNotFound {
                    headers.append(
                        HeaderRange(
                            level: level,
                            syntaxRange: syntaxRange,
                            contentRange: contentRange
                        ))
                }
            }
        }

        return headers
    }

    private func findBoldRanges(in text: String) -> [FormattingRange] {
        guard let regex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*", options: [])
        else { return [] }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let contentRange = match.range(at: 1)

            if fullRange.location != NSNotFound && contentRange.location != NSNotFound {
                let startSyntaxRange = NSRange(location: fullRange.location, length: 2)
                let endSyntaxRange = NSRange(
                    location: contentRange.location + contentRange.length, length: 2)

                return FormattingRange(
                    contentRange: contentRange,
                    syntaxRanges: [startSyntaxRange, endSyntaxRange]
                )
            }
            return nil
        }
    }

    private func findItalicRanges(in text: String) -> [FormattingRange] {
        guard
            let regex = try? NSRegularExpression(
                pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", options: [])
        else { return [] }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let contentRange = match.range(at: 1)

            if fullRange.location != NSNotFound && contentRange.location != NSNotFound {
                let startSyntaxRange = NSRange(location: fullRange.location, length: 1)
                let endSyntaxRange = NSRange(
                    location: contentRange.location + contentRange.length, length: 1)

                return FormattingRange(
                    contentRange: contentRange,
                    syntaxRanges: [startSyntaxRange, endSyntaxRange]
                )
            }
            return nil
        }
    }

    private func findInlineCodeRanges(in text: String) -> [FormattingRange] {
        guard let regex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) else {
            return []
        }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let contentRange = match.range(at: 1)

            if fullRange.location != NSNotFound && contentRange.location != NSNotFound {
                let startSyntaxRange = NSRange(location: fullRange.location, length: 1)
                let endSyntaxRange = NSRange(
                    location: contentRange.location + contentRange.length, length: 1)

                return FormattingRange(
                    contentRange: contentRange,
                    syntaxRanges: [startSyntaxRange, endSyntaxRange]
                )
            }
            return nil
        }
    }

    private func findCodeBlockRanges(in text: String) -> [CodeBlockRange] {
        guard
            let regex = try? NSRegularExpression(
                pattern: "```(\\w+)?\\n([\\s\\S]*?)```", options: [])
        else { return [] }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let languageRange = match.range(at: 1)
            let contentRange = match.range(at: 2)

            var language: String? = nil
            if languageRange.location != NSNotFound {
                language = String(text[Range(languageRange, in: text)!])
            }

            if fullRange.location != NSNotFound && contentRange.location != NSNotFound {
                return CodeBlockRange(
                    fullRange: fullRange,
                    contentRange: contentRange,
                    language: language
                )
            }
            return nil
        }
    }

    private func findLinkRanges(in text: String) -> [LinkRange] {
        guard
            let regex = try? NSRegularExpression(
                pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: [])
        else { return [] }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let textRange = match.range(at: 1)
            let urlRange = match.range(at: 2)

            if fullRange.location != NSNotFound && textRange.location != NSNotFound
                && urlRange.location != NSNotFound
            {
                return LinkRange(
                    fullRange: fullRange,
                    textRange: textRange,
                    urlRange: urlRange
                )
            }
            return nil
        }
    }

    private func findListRanges(in text: String) -> [ListRange] {
        guard
            let regex = try? NSRegularExpression(
                pattern: "^(\\s*)([-*+])(\\s+)(.+)$", options: [.anchorsMatchLines])
        else { return [] }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let _ = match.range(at: 1)  // indentRange
            let bulletRange = match.range(at: 2)
            let _ = match.range(at: 3)  // spaceRange
            let contentRange = match.range(at: 4)

            if fullRange.location != NSNotFound && contentRange.location != NSNotFound {
                return ListRange(
                    fullRange: fullRange,
                    bulletRange: bulletRange,
                    contentRange: contentRange
                )
            }
            return nil
        }
    }

    private func findQuoteRanges(in text: String) -> [QuoteRange] {
        guard
            let regex = try? NSRegularExpression(
                pattern: "^(>)(\\s+)(.+)$", options: [.anchorsMatchLines])
        else { return [] }
        let matches = regex.matches(in: text, options: [], range: NSRange(0..<text.count))

        return matches.compactMap { match in
            let fullRange = match.range
            let markerRange = match.range(at: 1)
            let contentRange = match.range(at: 3)

            if fullRange.location != NSNotFound && contentRange.location != NSNotFound {
                return QuoteRange(
                    fullRange: fullRange,
                    markerRange: markerRange,
                    contentRange: contentRange
                )
            }
            return nil
        }
    }

    // MARK: - Formatting Application Methods

    private func applyHeaders(
        _ headers: [HeaderRange], to textStorage: NSTextStorage, theme: IronTheme
    ) {
        for header in headers {
            // Hide syntax
            if header.syntaxRange.location + header.syntaxRange.length <= textStorage.length {
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor.clear, range: header.syntaxRange)
                textStorage.addAttribute(
                    .font, value: NSFont.systemFont(ofSize: 1), range: header.syntaxRange)
            }

            // Format content
            if header.contentRange.location + header.contentRange.length <= textStorage.length {
                let fontSize: CGFloat = max(32 - CGFloat(header.level - 1) * 4, 16)
                let headerFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)

                textStorage.addAttribute(.font, value: headerFont, range: header.contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor(theme.colors.accent),
                    range: header.contentRange)
            }
        }
    }

    private func applyBold(
        _ ranges: [FormattingRange], to textStorage: NSTextStorage, theme: IronTheme
    ) {
        for range in ranges {
            // Hide syntax
            for syntaxRange in range.syntaxRanges {
                if syntaxRange.location + syntaxRange.length <= textStorage.length {
                    textStorage.addAttribute(
                        .foregroundColor, value: NSColor.clear, range: syntaxRange)
                    textStorage.addAttribute(
                        .font, value: NSFont.systemFont(ofSize: 1), range: syntaxRange)
                }
            }

            // Format content
            if range.contentRange.location + range.contentRange.length <= textStorage.length {
                let boldFont = NSFont.systemFont(ofSize: 16, weight: .bold)
                textStorage.addAttribute(.font, value: boldFont, range: range.contentRange)
            }
        }
    }

    private func applyItalic(
        _ ranges: [FormattingRange], to textStorage: NSTextStorage, theme: IronTheme
    ) {
        for range in ranges {
            // Hide syntax
            for syntaxRange in range.syntaxRanges {
                if syntaxRange.location + syntaxRange.length <= textStorage.length {
                    textStorage.addAttribute(
                        .foregroundColor, value: NSColor.clear, range: syntaxRange)
                    textStorage.addAttribute(
                        .font, value: NSFont.systemFont(ofSize: 1), range: syntaxRange)
                }
            }

            // Format content
            if range.contentRange.location + range.contentRange.length <= textStorage.length {
                let italicFont =
                    NSFont.systemFont(ofSize: 16).italicVariant ?? NSFont.systemFont(ofSize: 16)
                textStorage.addAttribute(.font, value: italicFont, range: range.contentRange)
            }
        }
    }

    private func applyInlineCode(
        _ ranges: [FormattingRange], to textStorage: NSTextStorage, theme: IronTheme
    ) {
        for range in ranges {
            // Hide syntax
            for syntaxRange in range.syntaxRanges {
                if syntaxRange.location + syntaxRange.length <= textStorage.length {
                    textStorage.addAttribute(
                        .foregroundColor, value: NSColor.clear, range: syntaxRange)
                    textStorage.addAttribute(
                        .font, value: NSFont.systemFont(ofSize: 1), range: syntaxRange)
                }
            }

            // Format content
            if range.contentRange.location + range.contentRange.length <= textStorage.length {
                let codeFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                textStorage.addAttribute(.font, value: codeFont, range: range.contentRange)
                textStorage.addAttribute(
                    .backgroundColor, value: NSColor(theme.colors.accent).withAlphaComponent(0.1),
                    range: range.contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor(theme.colors.accent), range: range.contentRange
                )
            }
        }
    }

    private func applyCodeBlocks(
        _ blocks: [CodeBlockRange], to textStorage: NSTextStorage, theme: IronTheme
    ) {
        for block in blocks {
            // Ultra-safe bounds check
            guard block.fullRange.location >= 0,
                block.fullRange.location < textStorage.length,
                block.fullRange.location + block.fullRange.length <= textStorage.length,
                block.fullRange.length > 0
            else {
                continue
            }

            // Ultra-simple styling - just monospace font
            let codeFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            textStorage.addAttribute(.font, value: codeFont, range: block.fullRange)
        }
    }

    private func applyLinks(_ links: [LinkRange], to textStorage: NSTextStorage, theme: IronTheme) {
        for link in links {
            // Hide URL syntax
            let beforeText = NSRange(location: link.fullRange.location, length: 1)  // [
            let afterText = NSRange(
                location: link.textRange.location + link.textRange.length, length: 2)  // ](
            let urlAndClose = NSRange(
                location: link.urlRange.location, length: link.urlRange.length + 1)  // url)

            for syntaxRange in [beforeText, afterText, urlAndClose] {
                if syntaxRange.location + syntaxRange.length <= textStorage.length {
                    textStorage.addAttribute(
                        .foregroundColor, value: NSColor.clear, range: syntaxRange)
                    textStorage.addAttribute(
                        .font, value: NSFont.systemFont(ofSize: 1), range: syntaxRange)
                }
            }

            // Format link text
            if link.textRange.location + link.textRange.length <= textStorage.length {
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor(theme.colors.accent), range: link.textRange)
                textStorage.addAttribute(
                    .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: link.textRange)
            }
        }
    }

    private func applyLists(_ lists: [ListRange], to textStorage: NSTextStorage, theme: IronTheme) {
        for list in lists {
            // Style bullet
            if list.bulletRange.location + list.bulletRange.length <= textStorage.length {
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor(theme.colors.accent), range: list.bulletRange)

                // Replace - with •
                if textStorage.mutableString.substring(with: list.bulletRange) == "-" {
                    textStorage.mutableString.replaceCharacters(in: list.bulletRange, with: "•")
                }
            }

            // Format content (keep normal styling)
            if list.contentRange.location + list.contentRange.length <= textStorage.length {
                let baseFont = NSFont.systemFont(ofSize: 16)
                textStorage.addAttribute(.font, value: baseFont, range: list.contentRange)
            }
        }
    }

    private func applyQuotes(
        _ quotes: [QuoteRange], to textStorage: NSTextStorage, theme: IronTheme
    ) {
        for quote in quotes {
            // Hide quote marker
            if quote.markerRange.location + quote.markerRange.length <= textStorage.length {
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor.clear, range: quote.markerRange)
                textStorage.addAttribute(
                    .font, value: NSFont.systemFont(ofSize: 1), range: quote.markerRange)
            }

            // Format content
            if quote.contentRange.location + quote.contentRange.length <= textStorage.length {
                let italicFont =
                    NSFont.systemFont(ofSize: 16).italicVariant ?? NSFont.systemFont(ofSize: 16)
                textStorage.addAttribute(.font, value: italicFont, range: quote.contentRange)
                textStorage.addAttribute(
                    .foregroundColor, value: NSColor(theme.colors.foregroundSecondary),
                    range: quote.contentRange)
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            switch event.characters {
            case "b":
                toggleBold()
                return
            case "i":
                toggleItalic()
                return
            default:
                break
            }
        }

        super.keyDown(with: event)
    }

    private func toggleBold() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }

        if selectedRange.length > 0 {
            let selectedText = (string as NSString).substring(with: selectedRange)
            let boldText = "**\(selectedText)**"

            if shouldChangeText(in: selectedRange, replacementString: boldText) {
                replaceCharacters(in: selectedRange, with: boldText)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 2, length: selectedText.count))
            }
        }
    }

    private func toggleItalic() {
        guard let selectedRange = selectedRanges.first?.rangeValue else { return }

        if selectedRange.length > 0 {
            let selectedText = (string as NSString).substring(with: selectedRange)
            let italicText = "*\(selectedText)*"

            if shouldChangeText(in: selectedRange, replacementString: italicText) {
                replaceCharacters(in: selectedRange, with: italicText)
                setSelectedRange(
                    NSRange(location: selectedRange.location + 1, length: selectedText.count))
            }
        }
    }
}

// MARK: - Data Structures for Rendering

private struct RenderingData {
    var headers: [HeaderRange] = []
    var boldRanges: [FormattingRange] = []
    var italicRanges: [FormattingRange] = []
    var inlineCodeRanges: [FormattingRange] = []
    var codeBlockRanges: [CodeBlockRange] = []
    var linkRanges: [LinkRange] = []
    var listRanges: [ListRange] = []
    var quoteRanges: [QuoteRange] = []
}

private struct HeaderRange {
    let level: Int
    let syntaxRange: NSRange
    let contentRange: NSRange
}

private struct FormattingRange {
    let contentRange: NSRange
    let syntaxRanges: [NSRange]
}

private struct CodeBlockRange {
    let fullRange: NSRange
    let contentRange: NSRange
    let language: String?
}

private struct LinkRange {
    let fullRange: NSRange
    let textRange: NSRange
    let urlRange: NSRange
}

private struct ListRange {
    let fullRange: NSRange
    let bulletRange: NSRange
    let contentRange: NSRange
}

private struct QuoteRange {
    let fullRange: NSRange
    let markerRange: NSRange
    let contentRange: NSRange
}

// MARK: - NSFont Extension

extension NSFont {
    var italicVariant: NSFont? {
        let descriptor = fontDescriptor.withSymbolicTraits([.italic])
        return NSFont(descriptor: descriptor, size: pointSize)
    }
}

// MARK: - SwiftUI Preview

struct NotionStyleEditor_Previews: PreviewProvider {
    @State static var text = """
        # Welcome to Iron Notes

        This is a **Notion-style** editor with *live* markdown rendering.

        ## Features

        - Live formatting as you type
        - `Inline code` highlighting
        - [Links](https://example.com) work great

        > This is a blockquote that demonstrates the styling

        ### Code Example

        ```swift
        let code = "hello world"
        print(code)
        ```

        Regular text continues here with **bold** and *italic* formatting.
        """

    static var previews: some View {
        NotionStyleEditor(text: $text)
            .environmentObject(ThemeManager())
            .frame(width: 600, height: 400)
    }
}
