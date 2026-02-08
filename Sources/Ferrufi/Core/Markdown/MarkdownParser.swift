//
//  MarkdownParser.swift
//  Ferrufi
//
//  A simple, regex-based Markdown to HTML converter for previewing notes.
//

import Foundation
#if os(macOS)
import SwiftUI
import AppKit
#endif

@MainActor
public final class MarkdownParser {
    public static let shared = MarkdownParser()
    
    private init() {}
    
    public func parse(_ markdown: String, theme: ThemeColors) -> String {
        var html = markdown
        
        // 1. Headers
        html = applyRegex(html, pattern: #"^######\s+(.+)$"#, template: "<h6>$1</h6>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^#####\s+(.+)$"#, template: "<h5>$1</h5>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^####\s+(.+)$"#, template: "<h4>$1</h4>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^###\s+(.+)$"#, template: "<h3>$1</h3>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^##\s+(.+)$"#, template: "<h2>$1</h2>", options: .anchorsMatchLines)
        html = applyRegex(html, pattern: #"^#\s+(.+)$"#, template: "<h1>$1</h1>", options: .anchorsMatchLines)
        
        // 2. Bold & Italic
        html = applyRegex(html, pattern: #"\*\*\*(.+?)\*\*\*"#, template: "<strong><em>$1</em></strong>")
        html = applyRegex(html, pattern: #"\*\*(.+?)\*\*"#, template: "<strong>$1</strong>")
        html = applyRegex(html, pattern: #"\*(.+?)\*"#, template: "<em>$1</em>")
        
        // 3. Lists (Simple unordered)
        html = applyRegex(html, pattern: #"^\s*[\*\-]\s+(.+)$"#, template: "<li>$1</li>", options: .anchorsMatchLines)
        
        // 4. Runnable Mufi Code Blocks
        html = applyMufiRunBlocks(html)
        
        // 5. General Code Blocks
        html = applyRegex(html, pattern: #"```([a-z]*)\n?([\s\S]+?)\n?```"#, template: "<pre><code class=\"language-$1\">$2</code></pre>")
        html = applyRegex(html, pattern: #"`(.+?)`"#, template: "<code>$1</code>")
        
        // 6. Links
        html = applyRegex(html, pattern: #"\[(.+?)\]\((.+?)\)"#, template: "<a href=\"$2\">$1</a>")
        
        // 7. Wiki Links [[Target|Display]]
        html = applyRegex(html, pattern: #"\[\[(.+?)\|(.+?)\]\]"#, template: "<a href=\"#$1\">$2</a>")
        html = applyRegex(html, pattern: #"\[\[(.+?)\]\]"#, template: "<a href=\"#$1\">$1</a>")
        
        // 8. Line breaks
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        return wrapInHTML(html, theme: theme)
    }
    
    private func applyMufiRunBlocks(_ input: String) -> String {
        let pattern = #"```mufi\n?([\s\S]+?)\n?```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        
        let nsString = input as NSString
        var result = input
        var offset = 0
        
        let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let code = nsString.substring(with: match.range(at: 1))
            let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let id = "mufi-block-\(UUID().uuidString.prefix(8))"
            
            // Generate single-line HTML to avoid interference with the global newline-to-br replacement
            let html = "<div class=\"mufi-container\"><div class=\"mufi-header\"><div class=\"mufi-header-left\"><span class=\"mufi-dot\"></span><span class=\"mufi-label\">mufi</span></div><div class=\"mufi-actions\"><button class=\"action-btn run-btn\" title=\"Run Code\" onclick=\"runMufi('\(id)', '\(encodedCode)')\">▶ Run</button><button class=\"action-btn clear-btn\" title=\"Clear Output\" onclick=\"clearMufi('\(id)')\">✕ Clear</button></div></div><div class=\"mufi-content\"><pre><code>\(code)</code></pre></div><div id=\"output-\(id)\" class=\"mufi-output-container\" style=\"display:none;\"><div id=\"output-text-\(id)\" class=\"output-text\"></div></div></div>"
            
            let range = NSRange(location: match.range.location + offset, length: match.range.length)
            result = (result as NSString).replacingCharacters(in: range, with: html)
            offset += (html as NSString).length - match.range.length
        }
        
        return result
    }
    
    private func applyRegex(_ input: String, pattern: String, template: String, options: NSRegularExpression.Options = []) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return input }
        let range = NSRange(location: 0, length: input.utf16.count)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: template)
    }
    
    #if os(macOS)
    private func hexString(from color: Color) -> String {
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#000000" }
        
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        let a = Int(rgbColor.alphaComponent * 255)
        
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }
    #else
    private func hexString(from color: Color) -> String {
        let r = Int(color.red * 255)
        let g = Int(color.green * 255)
        let b = Int(color.blue * 255)
        let a = Int(color.opacity * 255)
        
        if a < 255 {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        } else {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
    }
    #endif
    
    private func wrapInHTML(_ body: String, theme: ThemeColors) -> String {
        let bgColor = hexString(from: theme.background)
        let textColor = hexString(from: theme.foreground)
        let accentColor = hexString(from: theme.accent)
        let borderColor = hexString(from: theme.border)
        let codeBgColor = hexString(from: theme.backgroundSecondary)
        
        #if os(macOS)
        let syntaxBgColor = hexString(from: theme.backgroundSecondary.opacity(0.5))
        #else
        let syntaxBgColor = hexString(from: Color(red: theme.backgroundSecondary.red, 
                                                 green: theme.backgroundSecondary.green, 
                                                 blue: theme.backgroundSecondary.blue, 
                                                 opacity: 0.5))
        #endif
        
        let htmlHead = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root {
                    --bg: \(bgColor);
                    --text: \(textColor);
                    --accent: \(accentColor);
                    --code-bg: \(codeBgColor);
                    --border: \(borderColor);
                    --syntax-bg: \(syntaxBgColor);
                    --header-bg: \(codeBgColor);
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    line-height: 1.4;
                    color: var(--text);
                    background-color: var(--bg);
                    padding: 24px;
                    max-width: 100%;
                    margin: 0;
                    -webkit-font-smoothing: antialiased;
                }

                h1 {
                    font-size: 1.8rem;
                    font-weight: 600;
                    margin-top: 0;
                    margin-bottom: 12px;
                    color: var(--text);
                }

                h2 {
                    font-size: 1.2rem;
                    font-weight: 700;
                    margin-top: 24px;
                    margin-bottom: 8px;
                    border-bottom: 1px solid var(--border);
                    padding-bottom: 4px;
                    color: var(--text);
                }

                h3 {
                    font-size: 1.0rem;
                    font-weight: 700;
                    margin-top: 16px;
                    margin-bottom: 6px;
                }

                p {
                    margin-bottom: 10px;
                }

                a {
                    color: var(--accent);
                    text-decoration: none;
                }

                a:hover {
                    text-decoration: underline;
                }

                code {
                    font-family: "SF Mono", "Fira Code", Menlo, Monaco, Courier, monospace;
                    background-color: var(--code-bg);
                    padding: 1px 4px;
                    border-radius: 3px;
                    font-size: 0.9em;
                }

                /* Syntax blocks - MATLAB style */
                pre:has(code) {
                    background-color: var(--syntax-bg);
                    padding: 12px 16px;
                    border-radius: 4px;
                    border-left: 3px solid var(--accent);
                    margin: 12px 0;
                    overflow-x: auto;
                }

                pre code {
                    background-color: transparent;
                    padding: 0;
                    border: none;
                    font-size: 0.95em;
                    color: var(--text);
                }

                /* Standard Markdown lists */
                ul, ol {
                    margin-bottom: 10px;
                    padding-left: 20px;
                }

                li {
                    margin-bottom: 4px;
                }

                /* Tables - Tight MATLAB style */
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 16px 0;
                    font-size: 0.95em;
                }

                th {
                    background-color: var(--header-bg);
                    text-align: left;
                    padding: 8px 12px;
                    border: 1px solid var(--border);
                    font-weight: 600;
                }

                td {
                    padding: 8px 12px;
                    border: 1px solid var(--border);
                    vertical-align: top;
                }

                /* Mufi Execution Blocks */
                .mufi-container {
                    background-color: var(--bg);
                    border: 1px solid var(--border);
                    border-radius: 6px;
                    margin: 16px 0;
                    overflow: hidden;
                }

                .mufi-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 4px 12px;
                    background: var(--header-bg);
                    border-bottom: 1px solid var(--border);
                }

                .mufi-label {
                    font-size: 10px;
                    font-weight: 700;
                    color: var(--accent);
                    text-transform: uppercase;
                }

                .mufi-actions {
                    display: flex;
                    gap: 8px;
                }

                .action-btn {
                    background: var(--accent);
                    color: white;
                    border: none;
                    border-radius: 3px;
                    padding: 2px 10px;
                    font-size: 10px;
                    font-weight: 600;
                    cursor: pointer;
                }

                .mufi-content pre {
                    margin: 0;
                    border: none;
                    background-color: transparent;
                    padding: 12px;
                }

                .mufi-output-container {
                    background-color: #1e1e1e;
                    color: #d4d4d4;
                    font-family: "SF Mono", monospace;
                    border-top: 1px solid #333;
                }

                .output-text {
                    padding: 12px;
                    font-size: 11px;
                }

                blockquote {
                    border-left: 4px solid var(--border);
                    margin: 16px 0;
                    padding: 8px 16px;
                    background-color: var(--header-bg);
                    color: var(--text);
                    font-style: italic;
                }

                ::-webkit-scrollbar {
                    width: 8px;
                }
                ::-webkit-scrollbar-track {
                    background: transparent;
                }
                ::-webkit-scrollbar-thumb {
                    background: rgba(128, 128, 128, 0.3);
                    border-radius: 4px;
                }
            </style>
            <script>
                function runMufi(id, encodedCode) {
                    const code = decodeURIComponent(encodedCode);
                    const container = document.getElementById('output-' + id);
                    const textDiv = document.getElementById('output-text-' + id);
                    
                    container.style.display = 'block';
                    textDiv.innerHTML = '<span style="color: #858585;">Running...</span>';
                    
                    // Communicate with Swift
                    #if os(macOS)
                    window.webkit.messageHandlers.ferrufiRunCode.postMessage({
                        id: id,
                        code: code
                    });
                    #endif
                }
                
                function clearMufi(id) {
                    const container = document.getElementById('output-' + id);
                    const textDiv = document.getElementById('output-text-' + id);
                    textDiv.innerHTML = '';
                    container.style.display = 'none';
                }
                
                // Called from Swift to update output
                window.updateMufiOutput = function(id, output) {
                    const textDiv = document.getElementById('output-text-' + id);
                    textDiv.innerHTML = output;
                }
            </script>
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