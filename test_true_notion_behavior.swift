#!/usr/bin/env swift

import Foundation

// Test script to verify true Notion-style syntax hiding behavior
print("🎯 Iron True Notion Behavior Test")
print(String(repeating: "=", count: 60))

// Test 1: Verify syntax hiding implementation
print("\n1️⃣ Testing Syntax Hiding Implementation...")

let notionEditorPath = "Sources/Iron/UI/Components/NotionStyleEditor.swift"
if FileManager.default.fileExists(atPath: notionEditorPath) {
    print("✅ NotionStyleEditor.swift exists")

    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        // Check for true syntax hiding features
        let syntaxHidingFeatures = [
            ("convertMarkdownToDisplay", "Markdown to display conversion"),
            ("processHeaders", "Header syntax removal"),
            ("processBold", "Bold syntax removal"),
            ("processItalic", "Italic syntax removal"),
            ("processInlineCode", "Code syntax removal"),
            ("processLinks", "Link syntax removal"),
            ("mutableString.setString", "Display text replacement"),
            ("renderedBlocks", "Block tracking for cursor management"),
            ("convertDisplayPositionToMarkdown", "Cursor position mapping"),
        ]

        for (feature, description) in syntaxHidingFeatures {
            if content.contains(feature) {
                print("✅ \(description): Found")
            } else {
                print("❌ \(description): Missing")
            }
        }

        // Check for proper text transformation patterns
        let transformations = [
            ("replaceCharacters(in: match.range, with: headerText)", "Header syntax removal"),
            ("replaceCharacters(in: match.range, with: boldText)", "Bold syntax removal"),
            ("replaceCharacters(in: match.range, with: italicText)", "Italic syntax removal"),
            ("replaceCharacters(in: match.range, with: codeText)", "Code syntax removal"),
            ("replaceCharacters(in: match.range, with: linkText)", "Link syntax removal"),
        ]

        for (pattern, description) in transformations {
            if content.contains(pattern) {
                print("✅ \(description): Implemented")
            } else {
                print("❌ \(description): Missing")
            }
        }

    } catch {
        print("❌ Failed to read NotionStyleEditor.swift: \(error)")
    }
} else {
    print("❌ NotionStyleEditor.swift missing")
}

// Test 2: Expected transformation behavior
print("\n2️⃣ Expected Transformation Behavior...")

let testCases = [
    ("# Big Header", "Big Header", "H1 syntax completely hidden"),
    ("## Medium Header", "Medium Header", "H2 syntax completely hidden"),
    ("### Small Header", "Small Header", "H3 syntax completely hidden"),
    ("**bold text here**", "bold text here", "Bold syntax completely hidden"),
    ("*italic text here*", "italic text here", "Italic syntax completely hidden"),
    ("`inline code here`", "inline code here", "Code syntax completely hidden"),
    ("[Link Text](https://example.com)", "Link Text", "Link syntax completely hidden"),
    ("- List item text", "• List item text", "List syntax transformed to bullet"),
    ("> Quote text here", "Quote text here", "Quote syntax completely hidden"),
]

print("📝 Expected transformations (input → display):")
for (input, expected, description) in testCases {
    print("   • \"\(input)\" → \"\(expected)\" (\(description))")
}

// Test 3: Dual content system verification
print("\n3️⃣ Dual Content System Verification...")

if FileManager.default.fileExists(atPath: notionEditorPath) {
    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        let dualSystemFeatures = [
            ("rawMarkdown:", "Raw markdown storage"),
            ("getMarkdownContent()", "Raw markdown getter"),
            ("setMarkdownContent", "Raw markdown setter"),
            ("renderMarkdownToDisplay()", "Display rendering"),
            ("insertText", "Text input handling"),
            ("deleteBackward", "Text deletion handling"),
        ]

        for (feature, description) in dualSystemFeatures {
            if content.contains(feature) {
                print("✅ \(description): Implemented")
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
            print("Build error: \(output)")
        }
    }
} catch {
    print("❌ Failed to run build: \(error)")
}

// Test 5: True Notion behavior specification
print("\n5️⃣ True Notion Behavior Specification...")

print(
    """
    🎯 TRUE Notion/Obsidian Behavior:

       What User Types:         What User Sees:         What Gets Saved:
       # Big Header            Big Header              # Big Header
       **bold text**           bold text               **bold text**
       *italic text*           italic text             *italic text*
       `inline code`           inline code             `inline code`
       [Link](url)             Link                    [Link](url)
       - List item             • List item             - List item
       > Quote text            Quote text              > Quote text

       Key Principles:
       ✨ Markdown SYNTAX is COMPLETELY HIDDEN from view
       ✨ Only the CONTENT is visible (no #, **, *, `, [], etc.)
       ✨ Content gets VISUAL STYLING (bold font, large size, colors)
       ✨ Raw markdown is preserved internally for saving
       ✨ Dual content system: display text ≠ saved text
       ✨ Cursor position mapping between display and raw content

       Implementation Requirements:
       📋 Text transformation: markdown → clean display text
       📋 Visual formatting: apply fonts, colors, sizes to display
       📋 Input handling: map user edits back to raw markdown
       📋 Cursor management: maintain position during transformations
       📋 Real-time updates: transform and format as user types
    """)

print("\n✅ True Notion Behavior Test Complete!")

print(
    """

    🚀 How to Test:
    1. Run: swift run IronApp
    2. Create or open a note
    3. Type: # My Big Header
    4. EXPECT: See "My Big Header" (large, bold) - NO # symbols visible
    5. Type: This is **bold** text
    6. EXPECT: See "This is bold text" (bold font) - NO ** symbols visible
    7. Type: Here's `some code`
    8. EXPECT: See "Here's some code" (monospace) - NO backticks visible

    🔍 Success Criteria:
    • NO markdown syntax visible in editor
    • Content appears with proper formatting (fonts, colors, sizes)
    • Typing is smooth with no disappearing characters
    • Raw markdown is preserved for file saving
    • Behaves EXACTLY like Notion, Obsidian, Typora

    🔧 If Syntax Still Visible:
    • The transformation functions are not working
    • Check processHeaders, processBold, processItalic methods
    • Verify mutableString.replaceCharacters calls
    • Ensure renderMarkdownToDisplay is being called
    • Debug the convertMarkdownToDisplay function
    """)
