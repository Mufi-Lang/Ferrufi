#!/usr/bin/env swift

//
//  debug_markdown.swift
//  Iron
//
//  Debug script to test markdown HTML generation
//

import Foundation

print("🔍 Debugging Markdown HTML Generation")
print("====================================")

// Simple test markdown
let testMarkdown = """
    # Hello World

    This is a **bold** text and *italic* text.

    ## Code Example

    Here's some `inline code`:

    ```swift
    func hello() {
        print("Hello, World!")
    }
    ```

    - List item 1
    - List item 2

    > This is a blockquote

    [Link example](https://example.com)
    """

print("\n📝 Input Markdown:")
print("─────────────────")
print(testMarkdown)

// Mock the basic processing steps
print("\n🔧 Processing Steps:")
print("──────────────────")

// Test header processing
var html = testMarkdown
print("1. Original length: \(html.count)")

// Simple header replacement (basic test)
html = html.replacingOccurrences(of: "# ", with: "<h1 class=\"header h1\">")
html = html.replacingOccurrences(of: "\n## ", with: "\n<h2 class=\"header h2\">")

print("2. After headers: \(html.count)")

// Test bold/italic
html = html.replacingOccurrences(of: "**", with: "<strong>", options: [], range: nil)
html = html.replacingOccurrences(of: "*", with: "<em>", options: [], range: nil)

print("3. After formatting: \(html.count)")

// Basic CSS generation test
let testCSS = """
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        color: #333333;
        background-color: #ffffff;
        margin: 20px;
        line-height: 1.6;
    }

    .header {
        margin: 16px 0;
        font-weight: 600;
        color: #1a1a1a;
    }

    .h1 {
        font-size: 2em;
        border-bottom: 1px solid #e1e4e8;
        padding-bottom: 8px;
    }

    .h2 {
        font-size: 1.5em;
        border-bottom: 1px solid #e1e4e8;
        padding-bottom: 6px;
    }

    strong {
        font-weight: 600;
        color: #24292e;
    }

    em {
        font-style: italic;
        color: #586069;
    }
    """

// Generate complete HTML
let completeHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
    \(testCSS)
        </style>
    </head>
    <body>
        <div class="markdown-content">
    \(html)
        </div>
    </body>
    </html>
    """

print("\n📄 Generated HTML:")
print("──────────────────")
print("HTML length: \(completeHTML.count) characters")
print("First 200 chars: \(String(completeHTML.prefix(200)))...")

// Save test HTML file for inspection
let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let htmlFile = currentDir + "/test_output.html"

do {
    try completeHTML.write(toFile: htmlFile, atomically: true, encoding: .utf8)
    print("\n💾 Saved test HTML to: test_output.html")
    print("   Open this file in a browser to see if basic HTML works")
} catch {
    print("\n❌ Failed to save HTML file: \(error)")
}

print("\n🎯 Debug Checklist:")
print("──────────────────")
print("□ Check if HTML structure is valid")
print("□ Verify CSS is properly embedded")
print("□ Test in browser to see visual output")
print("□ Compare with WebView behavior in app")

print("\n🔍 WebView Debug Tips:")
print("─────────────────────")
print("1. Check if WebView.loadHTMLString() is called")
print("2. Verify HTML content is not empty")
print("3. Check for JavaScript console errors")
print("4. Test if WebView delegate methods are called")

print("\n✨ Test complete! Check test_output.html in browser.")
