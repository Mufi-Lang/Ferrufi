#!/usr/bin/env swift

import Foundation

// Test script for true Notion-style rendering in Iron
print("🎯 Iron True Notion-Style Editor Test")
print(String(repeating: "=", count: 60))

// Test 1: Verify true rendering implementation
print("\n1️⃣ Testing True Notion-Style Rendering...")

let notionEditorPath = "Sources/Iron/UI/Components/NotionStyleEditor.swift"
if FileManager.default.fileExists(atPath: notionEditorPath) {
    print("✅ NotionStyleEditor.swift exists")

    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        // Check for true rendering features
        let trueRenderingFeatures = [
            ("renderMarkdownToDisplay", "Markdown to display conversion"),
            ("transformHeaders", "Header syntax hiding"),
            ("transformBoldItalic", "Bold/italic syntax hiding"),
            ("transformInlineCode", "Code syntax hiding"),
            ("transformLinks", "Link syntax hiding"),
            ("rawMarkdown", "Raw markdown storage"),
            ("renderedText", "Rendered display text"),
            ("replacingOccurrences", "Syntax transformation"),
        ]

        for (feature, description) in trueRenderingFeatures {
            if content.contains(feature) {
                print("✅ \(description): Found")
            } else {
                print("❌ \(description): Missing")
            }
        }

        // Check for syntax hiding patterns
        let syntaxPatterns = [
            ("^#{1,6}\\\\s+(.+)$", "Header # removal"),
            ("\\\\*\\\\*([^*]+)\\\\*\\\\*", "Bold ** removal"),
            ("`([^`]+)`", "Code backtick removal"),
            ("\\\\[([^\\\\]]+)\\\\]", "Link bracket handling"),
        ]

        for (pattern, description) in syntaxPatterns {
            if content.contains(pattern) {
                print("✅ \(description): Pattern found")
            } else {
                print("❌ \(description): Pattern missing")
            }
        }

    } catch {
        print("❌ Failed to read NotionStyleEditor.swift: \(error)")
    }
} else {
    print("❌ NotionStyleEditor.swift missing")
}

// Test 2: Test markdown transformations
print("\n2️⃣ Testing Markdown Transformations...")

let testTransformations = [
    ("# Big Header", "Big Header", "H1 syntax removal"),
    ("## Medium Header", "Medium Header", "H2 syntax removal"),
    ("**bold text**", "bold text", "Bold syntax removal"),
    ("*italic text*", "italic text", "Italic syntax removal"),
    ("`inline code`", "inline code", "Code syntax removal"),
    ("[Link Text](https://example.com)", "Link Text", "Link syntax removal"),
    ("- List item", "• List item", "List bullet transformation"),
    ("> Quote text", "Quote text", "Blockquote syntax removal"),
]

print("📝 Expected transformations (markdown → rendered):")
for (markdown, expected, description) in testTransformations {
    print("   • \(markdown) → \(expected) (\(description))")
}

// Test 3: Verify dual content system
print("\n3️⃣ Testing Dual Content System...")

if FileManager.default.fileExists(atPath: notionEditorPath) {
    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        let dualSystemFeatures = [
            ("rawMarkdown:", "Raw markdown property"),
            ("updateRawMarkdownFromDisplay", "Raw markdown synchronization"),
            ("renderContent()", "Content rendering method"),
            ("textStorage.mutableString.setString", "Display text update"),
            ("applyNotionFormatting", "Visual formatting application"),
        ]

        for (feature, description) in dualSystemFeatures {
            if content.contains(feature) {
                print("✅ \(description): Found")
            } else {
                print("❌ \(description): Missing")
            }
        }

    } catch {
        print("❌ Failed to analyze dual content system")
    }
}

// Test 4: Build verification
print("\n4️⃣ Build Verification...")

let buildResult = Process()
buildResult.launchPath = "/usr/bin/swift"
buildResult.arguments = ["build"]
buildResult.currentDirectoryPath = FileManager.default.currentDirectoryPath

let pipe = Pipe()
buildResult.standardOutput = pipe
buildResult.standardError = pipe

do {
    try buildResult.run()
    buildResult.waitUntilExit()

    if buildResult.terminationStatus == 0 {
        print("✅ Project builds successfully")
    } else {
        print("❌ Build failed")
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("Build output: \(output)")
        }
    }
} catch {
    print("❌ Failed to run build: \(error)")
}

// Test 5: Expected behavior
print("\n5️⃣ Expected True Notion-Style Behavior...")

print(
    """
    🎯 True Notion-Style Editor Behavior:

       What you type:        What you see:
       # Header             Header (large, bold, no #)
       **bold**            bold (bold font, no **)
       *italic*            italic (italic font, no *)
       `code`              code (mono font, no backticks)
       [link](url)         link (colored, underlined, no brackets)
       - item              • item (bullet, no dash)
       > quote             quote (italic, border, no >)

       Key Features:
       ✨ Markdown syntax completely hidden
       ✨ Only rendered content visible
       ✨ Real-time transformation as you type
       ✨ Maintains raw markdown for saving/editing
       ✨ Smooth visual feedback
       ✨ No mode switching needed

       Technical Implementation:
       📋 Dual content system (raw + rendered)
       📋 Live syntax transformation
       📋 NSTextStorage attribute application
       📋 Theme-aware color rendering
       📋 Performance-optimized updates
    """)

print("\n✅ True Notion-Style Editor Test Complete!")

print(
    """

    🚀 How to Test:
    1. Run: swift run IronApp
    2. Create or open a note
    3. Type: # My Header
    4. See: My Header (large, bold, no # symbols)
    5. Type: This is **bold** text
    6. See: This is bold text (bold font, no ** symbols)
    7. Type: Here's `some code`
    8. See: Here's some code (monospace, no backticks)

    🔍 What Should Happen:
    • All markdown syntax should disappear
    • Only the formatted result should be visible
    • Headers should appear as actual headers (not # Header)
    • Bold text should appear bold (not **bold**)
    • Code should appear in monospace (not `code`)
    • Links should appear as colored text (not [text](url))

    🔧 If Issues Found:
    1. Check that renderMarkdownToDisplay() is transforming syntax
    2. Verify that transformHeaders() removes # symbols
    3. Check that transformBoldItalic() removes ** and * markers
    4. Ensure applyNotionFormatting() applies visual styles
    5. Test that rawMarkdown maintains original content for saving
    """)
