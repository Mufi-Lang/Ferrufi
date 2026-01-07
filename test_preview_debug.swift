#!/usr/bin/env swift

import Foundation

// Test script to debug preview issues in Iron
print("🔍 Iron Preview Debug Test")
print(String(repeating: "=", count: 50))

// Test 1: Check if MarkdownRenderer files exist
print("\n1️⃣ Checking MarkdownRenderer files...")
let currentDir = FileManager.default.currentDirectoryPath
let rendererPath = "\(currentDir)/Sources/Iron/UI/Components/MarkdownRenderer.swift"
let webViewPath = "\(currentDir)/Sources/Iron/UI/Components/WebView.swift"

if FileManager.default.fileExists(atPath: rendererPath) {
    print("✅ MarkdownRenderer.swift exists")
} else {
    print("❌ MarkdownRenderer.swift missing")
}

if FileManager.default.fileExists(atPath: webViewPath) {
    print("✅ WebView.swift exists")
} else {
    print("❌ WebView.swift missing")
}

// Test 2: Check DetailView preview implementation
print("\n2️⃣ Checking DetailView preview implementation...")
let detailViewPath = "\(currentDir)/Sources/Iron/UI/Views/DetailView.swift"

if FileManager.default.fileExists(atPath: detailViewPath) {
    print("✅ DetailView.swift exists")

    do {
        let content = try String(contentsOfFile: detailViewPath, encoding: .utf8)

        if content.contains("WorkingMarkdownView") {
            print("✅ DetailView contains WorkingMarkdownView")
        } else {
            print("❌ DetailView missing WorkingMarkdownView")
        }

        if content.contains("previewView") {
            print("✅ DetailView has previewView property")
        } else {
            print("❌ DetailView missing previewView property")
        }

        if content.contains("showingPreview") {
            print("✅ DetailView has showingPreview state")
        } else {
            print("❌ DetailView missing showingPreview state")
        }

    } catch {
        print("❌ Failed to read DetailView.swift: \(error)")
    }
} else {
    print("❌ DetailView.swift missing")
}

// Test 3: Simple markdown processing test
print("\n3️⃣ Testing basic markdown processing...")

let testMarkdown = """
    # Test Header

    This is a **bold** text and *italic* text.

    ## Subheader

    - List item 1
    - List item 2

    ```swift
    let code = "hello world"
    ```

    [Link](https://example.com)
    """

print("📝 Test markdown:")
print(testMarkdown)
print("\n🔄 Processing...")

// Simulate basic markdown to HTML conversion
var html = testMarkdown

// Basic header processing
html = html.replacingOccurrences(
    of: #"^# (.+)$"#,
    with: "<h1>$1</h1>",
    options: .regularExpression
)

html = html.replacingOccurrences(
    of: #"^## (.+)$"#,
    with: "<h2>$1</h2>",
    options: .regularExpression
)

// Basic bold/italic
html = html.replacingOccurrences(
    of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
html = html.replacingOccurrences(
    of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)

// Basic links
html = html.replacingOccurrences(
    of: #"\[(.+?)\]\((.+?)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)

print("🎯 Basic HTML output:")
print(html)

// Test 4: Check for common issues
print("\n4️⃣ Checking for common preview issues...")

// Check if Components directory exists
let componentsPath = "\(currentDir)/Sources/Iron/UI/Components"
if FileManager.default.fileExists(atPath: componentsPath) {
    print("✅ Components directory exists")

    do {
        let components = try FileManager.default.contentsOfDirectory(atPath: componentsPath)
        print("📁 Components found: \(components.joined(separator: ", "))")
    } catch {
        print("❌ Failed to list components: \(error)")
    }
} else {
    print("❌ Components directory missing")
}

// Test 5: Check package dependencies
print("\n5️⃣ Checking Package.swift dependencies...")
let packagePath = "\(currentDir)/Package.swift"

if FileManager.default.fileExists(atPath: packagePath) {
    do {
        let packageContent = try String(contentsOfFile: packagePath, encoding: .utf8)

        if packageContent.contains("WebKit") {
            print("✅ WebKit dependency found")
        } else {
            print("⚠️ WebKit dependency not explicitly mentioned")
        }

        if packageContent.contains("SwiftUI") {
            print("✅ SwiftUI dependency found")
        } else {
            print("⚠️ SwiftUI dependency not explicitly mentioned")
        }

    } catch {
        print("❌ Failed to read Package.swift: \(error)")
    }
} else {
    print("❌ Package.swift missing")
}

// Test 6: Preview architecture analysis
print("\n6️⃣ Preview Architecture Analysis...")

print(
    """
    🏗️ Expected Preview Flow:
    1. User types in editor → editingText state updates
    2. WorkingMarkdownView receives new content
    3. WorkingMarkdownRenderer.content updates
    4. Renderer processes markdown → HTML
    5. WebView receives HTML and displays it

    🔍 Potential Issues to Check:
    - Is editingText binding working correctly?
    - Is WorkingMarkdownRenderer processing markdown?
    - Is WebView receiving non-empty HTML?
    - Are theme changes propagating correctly?
    - Is the WebView visible in the UI hierarchy?
    """)

print("\n✅ Debug test complete!")
print("\n🚀 Next Steps:")
print("1. Run the app with: swift run IronApp")
print("2. Check console output for WebView logs")
print("3. Try editing a note and watch preview updates")
print("4. Test theme switching with preview")
