//
//  MarkdownRenderer.swift
//  Ferrufi
//
//  Working markdown renderer with live preview
//

import Combine
import Foundation
import SwiftUI

/// Working markdown renderer with live preview
@MainActor
public class WorkingMarkdownRenderer: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var renderedHTML: String = ""
    @Published public private(set) var isRendering: Bool = false
    @Published public var content: String = "" {
        didSet {
            scheduleRender()
        }
    }

    // MARK: - Public Properties

    public var themeManager: ThemeManager?

    // MARK: - Private Properties

    private var renderTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupBindings()
    }

    // MARK: - Public Methods

    /// Force immediate render
    public func forceRender() {
        performRender()
    }

    // MARK: - Private Methods

    private func setupBindings() {
        $content
            .dropFirst()
            .sink { [weak self] _ in
                self?.scheduleRender()
            }
            .store(in: &cancellables)
    }

    private func scheduleRender() {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performRender()
            }
        }
    }

    private func performRender() {
        guard !content.isEmpty else {
            renderedHTML = ""
            return
        }

        isRendering = true
        let html = processMarkdown(content)
        print("📝 Rendered HTML length: \(html.count)")
        print("🎨 Theme manager exists: \(themeManager != nil)")
        if let theme = themeManager?.currentTheme {
            print("🎨 Current theme: \(theme.displayName)")
        }
        renderedHTML = html
        isRendering = false
    }

    private func processMarkdown(_ markdown: String) -> String {
        var html = markdown

        // Process markdown elements
        html = processHeaders(html)
        html = processCodeBlocks(html)
        html = processInlineCode(html)
        html = processBold(html)
        html = processItalic(html)
        html = processStrikethrough(html)
        html = processHighlights(html)
        html = processLinks(html)
        html = processImages(html)
        html = processWikiLinks(html)
        html = processTags(html)
        html = processLists(html)
        html = processBlockquotes(html)
        html = processHorizontalRules(html)
        html = processLineBreaks(html)

        return wrapInHTML(html)
    }

    // MARK: - Markdown Processing Methods

    private func processHeaders(_ text: String) -> String {
        var result = text
        let headerPatterns = [
            ("^#{6}\\s+(.+)$", "<h6 class=\"header h6\">$1</h6>"),
            ("^#{5}\\s+(.+)$", "<h5 class=\"header h5\">$1</h5>"),
            ("^#{4}\\s+(.+)$", "<h4 class=\"header h4\">$1</h4>"),
            ("^#{3}\\s+(.+)$", "<h3 class=\"header h3\">$1</h3>"),
            ("^#{2}\\s+(.+)$", "<h2 class=\"header h2\">$1</h2>"),
            ("^#{1}\\s+(.+)$", "<h1 class=\"header h1\">$1</h1>"),
        ]

        for (pattern, replacement) in headerPatterns {
            result = applyPattern(
                result, pattern: pattern, replacement: replacement, multiline: true)
        }

        return result
    }

    private func processCodeBlocks(_ text: String) -> String {
        // Fenced code blocks
        let fencedPattern = "```([a-zA-Z0-9_+-]*)\\n([\\s\\S]*?)```"
        var result = applyPattern(
            text,
            pattern: fencedPattern,
            replacement: "<pre class=\"code-block\" data-language=\"$1\"><code>$2</code></pre>"
        )

        // Indented code blocks
        let indentedPattern = "(?:^|\\n)((?:    |\\t).+(?:\\n(?:    |\\t).+)*)"
        result = applyPattern(
            result,
            pattern: indentedPattern,
            replacement: "<pre class=\"code-block\"><code>$1</code></pre>"
        )

        return result
    }

    private func processInlineCode(_ text: String) -> String {
        return applyPattern(
            text, pattern: "`([^`]+)`", replacement: "<code class=\"inline-code\">$1</code>")
    }

    private func processBold(_ text: String) -> String {
        var result = text
        result = applyPattern(
            result, pattern: "\\*\\*([^*]+)\\*\\*", replacement: "<strong>$1</strong>")
        result = applyPattern(result, pattern: "__([^_]+)__", replacement: "<strong>$1</strong>")
        return result
    }

    private func processItalic(_ text: String) -> String {
        var result = text
        result = applyPattern(result, pattern: "\\*([^*]+)\\*", replacement: "<em>$1</em>")
        result = applyPattern(result, pattern: "_([^_]+)_", replacement: "<em>$1</em>")
        return result
    }

    private func processStrikethrough(_ text: String) -> String {
        return applyPattern(text, pattern: "~~([^~]+)~~", replacement: "<del>$1</del>")
    }

    private func processHighlights(_ text: String) -> String {
        return applyPattern(text, pattern: "==([^=]+)==", replacement: "<mark>$1</mark>")
    }

    private func processLinks(_ text: String) -> String {
        var result = text

        // Markdown links [text](url)
        result = applyPattern(
            result,
            pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            replacement: "<a href=\"$2\" class=\"link\">$1</a>"
        )

        // Auto-links
        result = applyPattern(
            result,
            pattern: "(?<!\\]\\()https?://[^\\s]+",
            replacement: "<a href=\"$0\" class=\"auto-link\">$0</a>"
        )

        return result
    }

    private func processImages(_ text: String) -> String {
        return applyPattern(
            text,
            pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)",
            replacement: "<img src=\"$2\" alt=\"$1\" class=\"image\" />"
        )
    }

    private func processWikiLinks(_ text: String) -> String {
        return applyPattern(
            text,
            pattern: "\\[\\[([^\\]]+)\\]\\]",
            replacement: "<a href=\"#\" class=\"wiki-link\" data-target=\"$1\">$1</a>"
        )
    }

    private func processTags(_ text: String) -> String {
        return applyPattern(
            text,
            pattern: "(?:^|\\s)#([a-zA-Z0-9_-]+)",
            replacement: " <span class=\"tag\">#$1</span>"
        )
    }

    private func processLists(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var inOrderedList = false
        var inUnorderedList = false

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for ordered list
            if let match = trimmedLine.range(of: "^\\d+\\.\\s+(.+)$", options: .regularExpression) {
                let content = String(trimmedLine[match]).replacingOccurrences(
                    of: "^\\d+\\.\\s+", with: "", options: .regularExpression)

                if !inOrderedList {
                    if inUnorderedList {
                        processedLines.append("</ul>")
                        inUnorderedList = false
                    }
                    processedLines.append("<ol>")
                    inOrderedList = true
                }
                processedLines.append("<li>\(content)</li>")
            }
            // Check for unordered list
            else if let match = trimmedLine.range(
                of: "^[-*+]\\s+(.+)$", options: .regularExpression)
            {
                let content = String(trimmedLine[match]).replacingOccurrences(
                    of: "^[-*+]\\s+", with: "", options: .regularExpression)

                if !inUnorderedList {
                    if inOrderedList {
                        processedLines.append("</ol>")
                        inOrderedList = false
                    }
                    processedLines.append("<ul>")
                    inUnorderedList = true
                }
                processedLines.append("<li>\(content)</li>")
            }
            // Check for task list
            else if let match = trimmedLine.range(
                of: "^[-*+]\\s+\\[[ x]\\]\\s+(.+)$", options: .regularExpression)
            {
                let isChecked = trimmedLine.contains("[x]")
                let content = String(trimmedLine[match]).replacingOccurrences(
                    of: "^[-*+]\\s+\\[[ x]\\]\\s+", with: "", options: .regularExpression)
                let checkbox =
                    isChecked
                    ? "<input type=\"checkbox\" checked disabled class=\"task-checkbox\">"
                    : "<input type=\"checkbox\" disabled class=\"task-checkbox\">"

                if !inUnorderedList {
                    if inOrderedList {
                        processedLines.append("</ol>")
                        inOrderedList = false
                    }
                    processedLines.append("<ul class=\"task-list\">")
                    inUnorderedList = true
                }
                processedLines.append("<li class=\"task-item\">\(checkbox) \(content)</li>")
            } else {
                if inOrderedList {
                    processedLines.append("</ol>")
                    inOrderedList = false
                }
                if inUnorderedList {
                    processedLines.append("</ul>")
                    inUnorderedList = false
                }
                processedLines.append(line)
            }
        }

        if inOrderedList {
            processedLines.append("</ol>")
        }
        if inUnorderedList {
            processedLines.append("</ul>")
        }

        return processedLines.joined(separator: "\n")
    }

    private func processBlockquotes(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var inBlockquote = false

        for line in lines {
            if line.hasPrefix("> ") {
                if !inBlockquote {
                    inBlockquote = true
                    processedLines.append("<blockquote>")
                }
                let content = String(line.dropFirst(2))
                processedLines.append("<p>\(content)</p>")
            } else {
                if inBlockquote {
                    processedLines.append("</blockquote>")
                    inBlockquote = false
                }
                processedLines.append(line)
            }
        }

        if inBlockquote {
            processedLines.append("</blockquote>")
        }

        return processedLines.joined(separator: "\n")
    }

    private func processHorizontalRules(_ text: String) -> String {
        return applyPattern(
            text, pattern: "^---+$", replacement: "<hr class=\"rule\" />", multiline: true)
    }

    private func processLineBreaks(_ text: String) -> String {
        return
            text
            .replacingOccurrences(of: "\n\n+", with: "</p><p>", options: .regularExpression)
            .replacingOccurrences(
                of: "([^>])\n([^<])", with: "$1<br />$2", options: .regularExpression)
    }

    // MARK: - Helper Methods

    private func applyPattern(
        _ text: String,
        pattern: String,
        replacement: String,
        multiline: Bool = false
    ) -> String {
        var options: NSRegularExpression.Options = []
        if multiline {
            options.insert(.anchorsMatchLines)
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: replacement
        )
    }

    private func wrapInHTML(_ content: String) -> String {
        let css = generateCSS()
        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>\(css)</style>
            </head>
            <body>
                <div class="markdown-content">
                    \(content)
                </div>
            </body>
            </html>
            """
    }

    private func generateCSS() -> String {
        let theme = themeManager?.currentTheme.colors
        let bgColor: String
        let textColor: String
        let secondaryColor: String
        let accentColor: String
        let borderColor: String
        let codeBg: String

        if let themeColors = theme {
            bgColor = themeColors.background.toHex()
            textColor = themeColors.foreground.toHex()
            secondaryColor = themeColors.foregroundSecondary.toHex()
            accentColor = themeColors.accent.toHex()
            borderColor = themeColors.border.toHex()
            codeBg = themeColors.backgroundSecondary.toHex()
            print("🎨 Using theme colors: bg=\(bgColor), text=\(textColor), accent=\(accentColor)")
        } else {
            // Fallback colors
            let isDark = themeManager?.currentTheme.isDark == true
            bgColor = isDark ? "#0d1117" : "#ffffff"
            textColor = isDark ? "#c9d1d9" : "#333333"
            secondaryColor = isDark ? "#8b949e" : "#586069"
            accentColor = isDark ? "#58a6ff" : "#0366d6"
            borderColor = isDark ? "#30363d" : "#e1e4e8"
            codeBg = isDark ? "#161b22" : "#f6f8fa"
            print("⚠️ Using fallback colors")
        }

        return """
            * {
                box-sizing: border-box;
            }

            body {
                margin: 0;
                padding: 20px;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
                line-height: 1.6;
                color: \(textColor);
                background-color: \(bgColor);
            }

            .markdown-content {
                max-width: 100%;
            }

            .header {
                margin-top: 24px;
                margin-bottom: 16px;
                font-weight: 600;
                line-height: 1.25;
                color: \(textColor);
            }

            .h1 {
                font-size: 2em;
                border-bottom: 1px solid \(borderColor);
                padding-bottom: 8px;
                margin-top: 0;
            }
            .h2 {
                font-size: 1.5em;
                border-bottom: 1px solid \(borderColor);
                padding-bottom: 6px;
            }
            .h3 { font-size: 1.25em; }
            .h4 { font-size: 1em; }
            .h5 { font-size: 0.875em; }
            .h6 { font-size: 0.85em; color: \(secondaryColor); }

            p {
                margin-bottom: 16px;
            }

            .inline-code {
                padding: 2px 4px;
                font-size: 0.9em;
                background-color: \(codeBg);
                border-radius: 3px;
                font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Fira Code', monospace;
                color: \(accentColor);
            }

            .code-block {
                padding: 16px;
                overflow-x: auto;
                background-color: \(codeBg);
                border-radius: 6px;
                margin: 16px 0;
                position: relative;
            }

            .code-block code {
                padding: 0;
                background-color: transparent;
                font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Fira Code', monospace;
                font-size: 0.85em;
                color: \(textColor);
                white-space: pre;
            }

            .code-block[data-language]:not([data-language=""])::before {
                content: attr(data-language);
                position: absolute;
                top: 8px;
                right: 12px;
                font-size: 12px;
                color: \(secondaryColor);
                text-transform: uppercase;
                font-weight: 600;
            }

            blockquote {
                margin: 16px 0;
                padding-left: 16px;
                border-left: 4px solid \(borderColor);
                color: \(secondaryColor);
                font-style: italic;
            }

            blockquote p {
                margin: 8px 0;
            }

            ul, ol {
                padding-left: 24px;
                margin: 16px 0;
            }

            li {
                margin: 4px 0;
            }

            .task-list {
                list-style: none;
                padding-left: 0;
            }

            .task-item {
                display: flex;
                align-items: flex-start;
                margin: 8px 0;
            }

            .task-checkbox {
                margin-right: 8px;
                margin-top: 2px;
            }

            .rule {
                border: none;
                border-top: 1px solid \(borderColor);
                margin: 24px 0;
            }

            .link {
                color: \(accentColor);
                text-decoration: none;
            }

            .link:hover {
                text-decoration: underline;
            }

            .auto-link {
                color: \(accentColor);
                text-decoration: none;
                word-break: break-all;
            }

            .wiki-link {
                color: \(accentColor);
                background-color: \(accentColor)33;
                padding: 2px 6px;
                border-radius: 3px;
                text-decoration: none;
                font-weight: 500;
            }

            .wiki-link:hover {
                background-color: \(accentColor)66;
            }

            .tag {
                color: \(accentColor);
                background-color: \(accentColor)33;
                padding: 2px 8px;
                border-radius: 12px;
                font-size: 0.85em;
                font-weight: 500;
                display: inline-block;
                margin: 2px;
            }

            mark {
                background-color: #fff3cd;
                padding: 2px 4px;
                border-radius: 2px;
            }

            .image {
                max-width: 100%;
                height: auto;
                border-radius: 6px;
                margin: 8px 0;
                box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
            }

            strong {
                font-weight: 600;
                color: \(textColor);
            }

            em {
                font-style: italic;
                color: \(secondaryColor);
            }

            del {
                text-decoration: line-through;
                color: \(secondaryColor);
            }
            """
    }
}

// MARK: - SwiftUI View

public struct WorkingMarkdownView: View {
    @StateObject private var renderer: WorkingMarkdownRenderer
    @EnvironmentObject private var themeManager: ThemeManager

    let content: String

    public init(_ content: String) {
        self.content = content
        self._renderer = StateObject(wrappedValue: WorkingMarkdownRenderer())
    }

    public var body: some View {
        WebView(htmlContent: renderer.renderedHTML)
            .opacity(renderer.isRendering ? 0.7 : 1.0)
            .onChange(of: content) { _, newContent in
                renderer.content = newContent
            }
            .onChange(of: themeManager.currentTheme) { _, _ in
                renderer.themeManager = themeManager
                renderer.forceRender()
            }
            .onAppear {
                renderer.themeManager = themeManager
                renderer.content = content
            }
    }
}

// MARK: - Color Extension for Hex Conversion

extension Color {
    func toHex() -> String {
        // Convert SwiftUI Color to NSColor
        let nsColor = NSColor(self)

        // Convert to sRGB color space to ensure consistent color values
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else {
            // Fallback for unsupported color spaces
            print("⚠️ Color conversion failed, using fallback")
            return "#000000"
        }

        let red = Int(round(srgbColor.redComponent * 255))
        let green = Int(round(srgbColor.greenComponent * 255))
        let blue = Int(round(srgbColor.blueComponent * 255))

        // Clamp values to 0-255 range
        let clampedRed = max(0, min(255, red))
        let clampedGreen = max(0, min(255, green))
        let clampedBlue = max(0, min(255, blue))

        let hexColor = String(format: "#%02x%02x%02x", clampedRed, clampedGreen, clampedBlue)
        print("🎨 Color converted to hex: \(hexColor)")
        return hexColor
    }
}
