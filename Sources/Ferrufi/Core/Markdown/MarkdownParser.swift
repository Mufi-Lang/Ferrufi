//
//  MarkdownParser.swift
//  Ferrufi
//
//  A simple, regex-based Markdown to HTML converter for previewing notes.
//

import Foundation

@MainActor
public final class MarkdownParser {
    public static let shared = MarkdownParser()
    
    private init() {}
    
    public func parse(_ markdown: String) -> String {
        var html = markdown
        
        // 1. Headers
        html = applyRegex(html, pattern: #"^######\s+(.+)$"#, template: "<h6>$1</h6>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^#####\s+(.+)$"#, template: "<h5>$1</h5>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^####\s+(.+)$"#, template: "<h4>$1</h4>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^###\s+(.+)$"#, template: "<h3>$1</h3>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^##\s+(.+)$"#, template: "<h2>$1</h2>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^#\s+(.+)$"#, template: "<h1>$1</h1>", options: .anchorsMatchLines)
        
        // 2. Bold & Italic
        html = applyRegex(html, pattern: #"\*\*\*(.+?)\*\*"#, template: "<strong><em>$1</em></strong>")
        html = applyRegex(html, pattern: #"\*\*(.+?)\*"#, template: "<strong>$1</strong>")
        html = applyRegex(html, pattern: #"\*(.+?)\*"#, template: "<em>$1</em>")
        
        // 3. Lists (Simple unordered)
        html = applyRegex(html, pattern: #"^\s*[\*\-]\s+(.+)$"#, template: "<li>$1</li>", options: .anchorsMatchLines)
        
        // 4. Code
        html = applyRegex(html, pattern: #"```([a-z]*)\n?([\s\S]+?)\n?```"#, template: "<pre><code class=\"language-$1\">$2</code></pre>")
        html = applyRegex(html, pattern: #"`(.+?)`"#, template: "<code>$1</code>")
        
        // 5. Links
        html = applyRegex(html, pattern: #"\[(.+?)\]\((.+?)\)"#, template: "<a href=\"$2\">$1</a>")
        
        // 6. Wiki Links [[Target|Display]]
        html = applyRegex(html, pattern: #"\[\[(.+?)\|(.+?)\]\]"#, template: "<a href=\"#$1\">$2</a>")
        html = applyRegex(html, pattern: #"\[\[(.+?)\]\]"#, template: "<a href=\"#$1\">$1</a>")
        
        // 7. Line breaks
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        return wrapInHTML(html)
    }
    
    private func applyRegex(_ input: String, pattern: String, template: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return input }
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
    
    private func wrapInHTML(_ body: String) -> String {
        let htmlHead = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root {
                    --bg: #ffffff;
                    --text: #1a1a1a;
                    --accent: #007AFF;
                    --code-bg: #f5f5f5;
                    --border: #e5e5e5;
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #1a1b26;
                        --text: #c0caf5;
                        --accent: #7aa2f7;
                        --code-bg: #24283b;
                        --border: #3b4261;
                    }
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    color: var(--text);
                    background-color: var(--bg);
                    padding: 2rem;
                    max-width: 800px;
                    margin: 0 auto;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 1.5rem;
                    margin-bottom: 1rem;
                    font-weight: 600;
                }
                a {
                    color: var(--accent);
                    text-decoration: none;
                }
                a:hover {
                    text-decoration: underline;
                }
                code {
                    font-family: "SF Mono", Menlo, Monaco, Courier, monospace;
                    background-color: var(--code-bg);
                    padding: 0.2rem 0.4rem;
                    border-radius: 4px;
                    font-size: 0.9em;
                }
                pre {
                    background-color: var(--code-bg);
                    padding: 1rem;
                    border-radius: 8px;
                    overflow-x: auto;
                    border: 1px solid var(--border);
                }
                pre code {
                    padding: 0;
                    background-color: transparent;
                }
                blockquote {
                    border-left: 4px solid var(--accent);
                    margin: 0;
                    padding-left: 1rem;
                    color: var(--text);
                    opacity: 0.8;
                }
                hr {
                    border: 0;
                    border-top: 1px solid var(--border);
                    margin: 2rem 0;
                }
            </style>
        </head>
        <body>
        """
        
        let htmlFoot = """
        </body>
        </html>
        """
        
        return htmlHead + body + htmlFoot
    }
}