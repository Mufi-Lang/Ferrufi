//
//  MarkdownPreview.swift
//  Iron
//
//  Created on 2024-12-19.
//

import AppKit
import Foundation
import SwiftUI
import WebKit

/// A markdown preview component that renders markdown text as formatted HTML
struct MarkdownPreview: NSViewRepresentable {
    let markdown: String
    let baseURL: URL?

    @Environment(\.colorScheme) var colorScheme

    init(markdown: String, baseURL: URL? = nil) {
        self.markdown = markdown
        self.baseURL = baseURL
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        // Configure webView
        webView.setValue(false, forKey: "drawsBackground")
        webView.isHidden = false

        // Disable user interaction for preview
        // Note: javaScriptEnabled is deprecated, using alternative approach

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func generateHTML() -> String {
        let renderer = MarkdownRenderer()
        let htmlContent = renderer.renderToHTML(markdown)

        let isDark = colorScheme == .dark
        let css = generateCSS(isDark: isDark)

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                \(css)
                </style>
            </head>
            <body>
                \(htmlContent)
            </body>
            </html>
            """
    }

    private func generateCSS(isDark: Bool) -> String {
        let backgroundColor = isDark ? "#1e1e1e" : "#ffffff"
        let textColor = isDark ? "#d4d4d4" : "#000000"
        let secondaryTextColor = isDark ? "#9d9d9d" : "#666666"
        let borderColor = isDark ? "#404040" : "#e1e1e1"
        let codeBackgroundColor = isDark ? "#2d2d2d" : "#f6f6f6"
        let linkColor = isDark ? "#569cd6" : "#0066cc"
        let blockquoteColor = isDark ? "#808080" : "#666666"
        let headerColor = isDark ? "#4ec9b0" : "#0066cc"

        return """
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                font-size: 14px;
                line-height: 1.6;
                color: \(textColor);
                background-color: \(backgroundColor);
                padding: 16px;
                margin: 0;
                max-width: none;
            }

            /* Headers */
            h1, h2, h3, h4, h5, h6 {
                color: \(headerColor);
                font-weight: 600;
                margin-top: 24px;
                margin-bottom: 12px;
                line-height: 1.3;
            }

            h1 { font-size: 2em; border-bottom: 2px solid \(borderColor); padding-bottom: 8px; }
            h2 { font-size: 1.6em; border-bottom: 1px solid \(borderColor); padding-bottom: 4px; }
            h3 { font-size: 1.4em; }
            h4 { font-size: 1.2em; }
            h5 { font-size: 1.1em; }
            h6 { font-size: 1em; }

            /* Paragraphs */
            p {
                margin: 0 0 16px 0;
            }

            /* Links */
            a {
                color: \(linkColor);
                text-decoration: none;
            }

            a:hover {
                text-decoration: underline;
            }

            /* Code */
            code {
                background-color: \(codeBackgroundColor);
                border: 1px solid \(borderColor);
                border-radius: 3px;
                font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
                font-size: 0.9em;
                padding: 2px 4px;
            }

            pre {
                background-color: \(codeBackgroundColor);
                border: 1px solid \(borderColor);
                border-radius: 6px;
                font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
                font-size: 0.9em;
                line-height: 1.4;
                margin: 16px 0;
                overflow-x: auto;
                padding: 16px;
            }

            pre code {
                background: none;
                border: none;
                padding: 0;
            }

            /* Lists */
            ul, ol {
                margin: 0 0 16px 0;
                padding-left: 24px;
            }

            li {
                margin: 4px 0;
            }

            ul ul, ol ol, ul ol, ol ul {
                margin: 0;
            }

            /* Blockquotes */
            blockquote {
                border-left: 4px solid \(borderColor);
                color: \(blockquoteColor);
                font-style: italic;
                margin: 16px 0;
                padding: 0 16px;
            }

            blockquote p {
                margin: 8px 0;
            }

            /* Tables */
            table {
                border-collapse: collapse;
                margin: 16px 0;
                width: 100%;
            }

            th, td {
                border: 1px solid \(borderColor);
                padding: 8px 12px;
                text-align: left;
            }

            th {
                background-color: \(codeBackgroundColor);
                font-weight: 600;
            }

            tr:nth-child(even) {
                background-color: \(isDark ? "#2a2a2a" : "#f9f9f9");
            }

            /* Horizontal Rules */
            hr {
                background-color: \(borderColor);
                border: none;
                height: 1px;
                margin: 24px 0;
            }

            /* Images */
            img {
                max-width: 100%;
                height: auto;
                border-radius: 4px;
            }

            /* Task Lists */
            input[type="checkbox"] {
                margin-right: 8px;
            }

            /* Wiki Links */
            .wiki-link {
                color: \(isDark ? "#4ec9b0" : "#0066cc");
                background-color: \(isDark ? "rgba(78, 201, 176, 0.1)" : "rgba(0, 102, 204, 0.1)");
                padding: 2px 4px;
                border-radius: 3px;
                text-decoration: none;
            }

            .wiki-link:hover {
                background-color: \(isDark ? "rgba(78, 201, 176, 0.2)" : "rgba(0, 102, 204, 0.2)");
            }

            /* Tags */
            .tag {
                color: \(isDark ? "#dcdcaa" : "#795e26");
                font-weight: 600;
            }

            /* Highlights */
            mark {
                background-color: \(isDark ? "#3c3c3c" : "#ffff00");
                padding: 1px 2px;
                border-radius: 2px;
            }

            /* Strikethrough */
            del {
                color: \(secondaryTextColor);
                text-decoration: line-through;
            }

            /* Math (if supported) */
            .math {
                font-family: 'Times New Roman', serif;
            }
            """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownPreview

        init(_ parent: MarkdownPreview) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    // Handle different link types
                    let urlString = url.absoluteString

                    if urlString.hasPrefix("file://") {
                        // Internal file link - could navigate to another note
                        NotificationCenter.default.post(name: .openFileLink, object: url)
                    } else if urlString.contains("[[") && urlString.contains("]]") {
                        // Wiki link - extract note name and navigate
                        let noteName = urlString.replacingOccurrences(of: "[[", with: "")
                            .replacingOccurrences(of: "]]", with: "")
                        NotificationCenter.default.post(name: .openWikiLink, object: noteName)
                    } else {
                        // External link - open in default browser
                        NSWorkspace.shared.open(url)
                    }
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

/// Renders markdown text to HTML
class MarkdownRenderer {

    func renderToHTML(_ markdown: String) -> String {
        // This is a basic markdown renderer
        // In a production app, you'd want to use a library like CommonMark or similar

        var html = markdown

        // Process in order to avoid conflicts
        html = processCodeBlocks(html)
        html = processHeaders(html)
        html = processLists(html)
        html = processBlockquotes(html)
        html = processHorizontalRules(html)
        html = processInlineCode(html)
        html = processBold(html)
        html = processItalic(html)
        html = processStrikethrough(html)
        html = processLinks(html)
        html = processWikiLinks(html)
        html = processTags(html)
        html = processLineBreaks(html)

        return html
    }

    private func processCodeBlocks(_ text: String) -> String {
        let pattern = #"```([\s\S]*?)```"#
        return text.replacingOccurrences(
            of: pattern,
            with: "<pre><code>$1</code></pre>",
            options: .regularExpression
        )
    }

    private func processHeaders(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processedLines: [String] = []

        for line in lines {
            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
                if level >= 1 && level <= 6 && !content.isEmpty {
                    processedLines.append("<h\(level)>\(content)</h\(level)>")
                } else {
                    processedLines.append(line)
                }
            } else {
                processedLines.append(line)
            }
        }

        return processedLines.joined(separator: "\n")
    }

    private func processLists(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var inUnorderedList = false
        var inOrderedList = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inUnorderedList {
                    processedLines.append("<ul>")
                    inUnorderedList = true
                }
                if inOrderedList {
                    processedLines.append("</ol>")
                    inOrderedList = false
                }
                let content = String(trimmed.dropFirst(2))
                processedLines.append("<li>\(content)</li>")
            } else if trimmed.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                if !inOrderedList {
                    processedLines.append("<ol>")
                    inOrderedList = true
                }
                if inUnorderedList {
                    processedLines.append("</ul>")
                    inUnorderedList = false
                }
                let content = trimmed.replacingOccurrences(
                    of: #"^\d+\. "#, with: "", options: .regularExpression)
                processedLines.append("<li>\(content)</li>")
            } else {
                if inUnorderedList {
                    processedLines.append("</ul>")
                    inUnorderedList = false
                }
                if inOrderedList {
                    processedLines.append("</ol>")
                    inOrderedList = false
                }
                processedLines.append(line)
            }
        }

        if inUnorderedList {
            processedLines.append("</ul>")
        }
        if inOrderedList {
            processedLines.append("</ol>")
        }

        return processedLines.joined(separator: "\n")
    }

    private func processBlockquotes(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var processedLines: [String] = []
        var inBlockquote = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                if !inBlockquote {
                    processedLines.append("<blockquote>")
                    inBlockquote = true
                }
                let content = line.replacingOccurrences(
                    of: #"^\s*>\s?"#, with: "", options: .regularExpression)
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
        return text.replacingOccurrences(
            of: #"^---+$"#,
            with: "<hr>",
            options: .regularExpression
        )
    }

    private func processInlineCode(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "<code>$1</code>",
            options: .regularExpression
        )
    }

    private func processBold(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"\*\*(.*?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
    }

    private func processItalic(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"\*(.*?)\*"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
    }

    private func processStrikethrough(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"~~(.*?)~~"#,
            with: "<del>$1</del>",
            options: .regularExpression
        )
    }

    private func processLinks(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )
    }

    private func processWikiLinks(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"\[\[([^\]]+)\]\]"#,
            with: "<a href=\"wiki://$1\" class=\"wiki-link\">$1</a>",
            options: .regularExpression
        )
    }

    private func processTags(_ text: String) -> String {
        return text.replacingOccurrences(
            of: #"#([\w-]+)"#,
            with: "<span class=\"tag\">#$1</span>",
            options: .regularExpression
        )
    }

    private func processLineBreaks(_ text: String) -> String {
        // Convert double newlines to paragraphs
        let paragraphs = text.components(separatedBy: "\n\n")
        var processedParagraphs: [String] = []

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("<") {
                processedParagraphs.append(
                    "<p>\(trimmed.replacingOccurrences(of: "\n", with: "<br>"))</p>")
            } else {
                processedParagraphs.append(trimmed)
            }
        }

        return processedParagraphs.joined(separator: "\n\n")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openFileLink = Notification.Name("openFileLink")
    static let openWikiLink = Notification.Name("openWikiLink")
}
