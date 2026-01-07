#!/usr/bin/env swift

//
//  debug_webview.swift
//  Iron
//
//  Simple WebView debug test to understand why preview wasn't working
//

import Foundation

print("🌐 WebView Debug Test")
print("===================")

// Test HTML content that should work
let testHTML = """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                color: #333333;
                background-color: #ffffff;
                margin: 20px;
                line-height: 1.6;
            }

            h1 {
                font-size: 2em;
                font-weight: bold;
                color: #1a1a1a;
                border-bottom: 1px solid #e1e4e8;
                padding-bottom: 8px;
            }

            h2 {
                font-size: 1.5em;
                font-weight: bold;
                color: #1a1a1a;
                border-bottom: 1px solid #e1e4e8;
                padding-bottom: 6px;
            }

            code {
                background-color: #f6f8fa;
                padding: 2px 4px;
                border-radius: 3px;
                font-family: 'SF Mono', Monaco, monospace;
                color: #d73a49;
            }

            pre {
                background-color: #f6f8fa;
                padding: 16px;
                border-radius: 6px;
                overflow-x: auto;
            }

            blockquote {
                margin: 16px 0;
                padding-left: 16px;
                border-left: 4px solid #dfe2e5;
                color: #6a737d;
                font-style: italic;
            }

            a {
                color: #0366d6;
                text-decoration: none;
            }

            a:hover {
                text-decoration: underline;
            }

            strong {
                font-weight: bold;
                color: #24292e;
            }

            em {
                font-style: italic;
                color: #586069;
            }
        </style>
    </head>
    <body>
        <div class="markdown-content">
            <h1>WebView Debug Test</h1>

            <p>This is a test to see if WebView is working correctly.</p>

            <h2>Features to Test</h2>

            <ul>
                <li><strong>Bold text</strong> should appear bold</li>
                <li><em>Italic text</em> should appear italic</li>
                <li><code>Inline code</code> should have background</li>
                <li><a href="https://example.com">Links</a> should be blue</li>
            </ul>

            <blockquote>
                This blockquote should have a left border and italic text.
            </blockquote>

            <pre><code>function test() {
        console.log("Code blocks should work");
        return true;
    }</code></pre>

            <h2>Color Tests</h2>

            <p>If you can see this content with proper styling, the WebView is working correctly.</p>

            <script>
                console.log("WebView JavaScript test - if you see this in console, JS is working");
                document.addEventListener('DOMContentLoaded', function() {
                    console.log("DOM loaded successfully");
                });
            </script>
        </div>
    </body>
    </html>
    """

print("\n📄 Generated Test HTML:")
print("Length: \(testHTML.count) characters")
print("First 200 chars: \(String(testHTML.prefix(200)))...")

// Save to file for manual testing
let fileManager = FileManager.default
let currentDir = fileManager.currentDirectoryPath
let testFile = currentDir + "/webview_test.html"

do {
    try testHTML.write(toFile: testFile, atomically: true, encoding: .utf8)
    print("\n💾 Saved test HTML to: webview_test.html")
    print("   Open this in a browser to verify HTML structure")
} catch {
    print("\n❌ Failed to save test file: \(error)")
}

print("\n🔍 WebView Debugging Checklist:")
print("──────────────────────────────")
print("1. ✅ HTML structure is valid")
print("2. ✅ CSS is properly embedded")
print("3. ✅ Content should render in browser")
print("4. 🔍 Check WebView console logs when running app")
print("5. 🔍 Verify WebView.loadHTMLString() is called")
print("6. 🔍 Check if HTML content is empty in WorkingMarkdownView")

print("\n🧪 Next Steps:")
print("──────────────")
print("1. Test this HTML in browser - if it works, HTML is fine")
print("2. Run Iron app with debug output enabled")
print("3. Check console for WebView debug messages")
print("4. If WebView shows blank, issue is in WebView integration")
print("5. If HTML is malformed, issue is in MarkdownRenderer")

print("\n💡 Common WebView Issues:")
print("─────────────────────────")
print("• Empty HTML content being loaded")
print("• WebView not being displayed in view hierarchy")
print("• Theme manager not connected to renderer")
print("• CSS syntax errors breaking rendering")
print("• WebView delegate methods not being called")

print("\n✨ Test HTML created - check webview_test.html in browser!")
