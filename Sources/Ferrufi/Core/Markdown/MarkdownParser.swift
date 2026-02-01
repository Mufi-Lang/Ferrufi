//
//  MarkdownParser.swift
//  Ferrufi
//
//  A simple, regex-based Markdown to HTML converter for previewing notes.
//

import Foundation
import SwiftUI
import AppKit

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
            let html = "<div class=\"mufi-container\"><div class=\"mufi-header\"><div class=\"mufi-header-left\"><span class=\"mufi-dot\"></span><span class=\"mufi-label\">mufi</span></div><div class=\"mufi-actions\"><button class=\"action-btn run-btn\" title=\"Run Code\" onclick=\"runMufi('\(id)', '\(encodedCode)')\">▶</button><button class=\"action-btn clear-btn\" title=\"Clear Output\" onclick=\"clearMufi('\(id)')\">✕</button></div></div><div class=\"mufi-content\"><pre><code>\(code)</code></pre></div><div id=\"output-\(id)\" class=\"mufi-output-container\" style=\"display:none;\"><div id=\"output-text-\(id)\" class=\"output-text\"></div></div></div>"
            
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
    
    private func wrapInHTML(_ body: String, theme: ThemeColors) -> String {
        let bgColor = hexString(from: theme.background)
        let textColor = hexString(from: theme.foreground)
        let accentColor = hexString(from: theme.accent)
        let borderColor = hexString(from: theme.border)
        let codeBgColor = hexString(from: theme.backgroundSecondary)
        
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
                    margin: 1rem 0;
                }
                pre code {
                    padding: 0;
                    background-color: transparent;
                }
                
                /* Mufi Block Styles - Modern IDE Aesthetic */
                .mufi-container {
                    background-color: var(--code-bg);
                    border: 1px solid var(--border);
                    border-radius: 8px;
                    margin: 1.2rem 0;
                    overflow: hidden;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.08);
                    display: block;
                    padding: 0 !important;
                }
                .mufi-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 0 10px;
                    background: var(--border);
                    background: linear-gradient(to bottom, var(--border), var(--code-bg));
                    border-bottom: 1px solid var(--border);
                    height: 24px;
                    margin: 0 !important;
                }
                .mufi-header-left {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                }
                .mufi-dot {
                    width: 6px;
                    height: 6px;
                    background-color: var(--accent);
                    border-radius: 50%;
                }
                .mufi-label {
                    font-size: 10px;
                    font-weight: 700;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    color: var(--text);
                    opacity: 0.7;
                }
                .mufi-actions {
                    display: flex;
                    gap: 4px;
                }
                .action-btn {
                    background: transparent;
                    color: var(--text);
                    border: none;
                    border-radius: 3px;
                    padding: 2px 6px;
                    font-size: 10px;
                    cursor: pointer;
                    transition: all 0.1s;
                    display: flex;
                    align-items: center;
                    opacity: 0.6;
                }
                .action-btn:hover {
                    background-color: rgba(0,0,0,0.1);
                    opacity: 1;
                }
                @media (prefers-color-scheme: dark) {
                    .action-btn:hover {
                        background-color: rgba(255,255,255,0.1);
                    }
                }
                .run-btn {
                    color: var(--accent);
                }
                .run-btn {
                    color: var(--accent);
                    font-weight: 600;
                }
                .run-btn .btn-icon {
                    font-size: 9px;
                }
                .clear-btn {
                    opacity: 0.6;
                    padding: 3px 6px;
                }
                .clear-btn .btn-icon {
                    font-size: 8px;
                }
                .mufi-content pre {
                    margin: 0;
                    border: none;
                    border-radius: 0;
                    background-color: transparent;
                    padding: 16px;
                }
                .mufi-content code {
                    background-color: transparent;
                    padding: 0;
                    font-size: 13px;
                    line-height: 1.5;
                }
                
                /* Output Container */
                .mufi-output-container {
                    background-color: #1e1e1e;
                    color: #d4d4d4;
                    border-top: 1px solid #333;
                    font-family: "SF Mono", Menlo, Monaco, Courier, monospace;
                    overflow: hidden;
                    animation: slideDown 0.3s ease-out;
                }
                .output-header {
                    font-size: 9px;
                    text-transform: uppercase;
                    letter-spacing: 1px;
                    padding: 4px 12px;
                    background-color: #252526;
                    color: #858585;
                    border-bottom: 1px solid #333;
                }
                .output-text {
                    padding: 12px;
                    font-size: 12px;
                    line-height: 1.4;
                    white-space: pre-wrap;
                    max-height: 250px;
                    overflow-y: auto;
                }
                
                @keyframes slideDown {
                    from { max-height: 0; opacity: 0; }
                    to { max-height: 300px; opacity: 1; }
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
            <script>
                function runMufi(id, encodedCode) {
                    const code = decodeURIComponent(encodedCode);
                    const container = document.getElementById('output-' + id);
                    const textDiv = document.getElementById('output-text-' + id);
                    
                    container.style.display = 'block';
                    textDiv.innerHTML = '<span style="color: #858585;">Running...</span>';
                    
                    // Communicate with Swift
                    window.webkit.messageHandlers.ferrufiRunCode.postMessage({
                        id: id,
                        code: code
                    });
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