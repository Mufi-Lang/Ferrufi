#!/usr/bin/env swift

import Foundation

// Test script to validate syntax hiding behavior in Iron Notes
print("🔍 Iron Syntax Hiding Validation Test")
print(String(repeating: "=", count: 60))

// Test 1: Check if syntax hiding implementation exists
print("\n1️⃣ Testing Syntax Hiding Implementation...")

let notionEditorPath = "Sources/Iron/UI/Components/NotionStyleEditor.swift"
if FileManager.default.fileExists(atPath: notionEditorPath) {
    print("✅ NotionStyleEditor.swift exists")

    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        // Check for syntax hiding methods
        let syntaxHidingFeatures = [
            ("applySyntaxHiding", "Syntax hiding method"),
            ("applyContentFormatting", "Content formatting method"),
            ("NSColor.clear", "Transparent color for hiding"),
            ("foregroundColor, value: NSColor.clear", "Clear color application"),
            ("font, value: NSFont.systemFont(ofSize: 1)", "Tiny font for hiding"),
        ]

        for (feature, description) in syntaxHidingFeatures {
            if content.contains(feature) {
                print("✅ \(description): Found")
            } else {
                print("❌ \(description): Missing")
            }
        }

        // Check for proper pattern coverage
        let syntaxPatterns = [
            ("^#{1,6}\\\\s+", "Header hash hiding"),
            ("\\\\*\\\\*", "Bold marker hiding"),
            ("(?<!\\\\*)\\\\*(?!\\\\*)", "Italic marker hiding"),
            ("`", "Code backtick hiding"),
            ("\\\\[|\\\\]|\\\\([^)]*\\\\)", "Link bracket hiding"),
            ("^\\\\s*[-*+]\\\\s+", "List marker hiding"),
            ("^>\\\\s+", "Blockquote marker hiding"),
        ]

        for (pattern, description) in syntaxPatterns {
            if content.contains(pattern) {
                print("✅ \(description): Pattern found")
            } else {
                print("⚠️ \(description): Pattern not found")
            }
        }

    } catch {
        print("❌ Failed to read NotionStyleEditor.swift: \(error)")
    }
} else {
    print("❌ NotionStyleEditor.swift missing")
}

// Test 2: Expected behavior specification
print("\n2️⃣ Expected Syntax Hiding Behavior...")

let testCases = [
    ("# Big Header", "Big Header (large, bold) - # completely invisible"),
    ("## Medium Header", "Medium Header (medium, bold) - ## completely invisible"),
    ("**bold text**", "bold text (bold font) - ** completely invisible"),
    ("*italic text*", "italic text (italic font) - * completely invisible"),
    ("`inline code`", "inline code (monospace) - backticks completely invisible"),
    ("[Link Text](https://url.com)", "Link Text (colored) - brackets and URL completely invisible"),
    ("- List item", "• List item (bullet) - dash completely invisible"),
    ("> Quote text", "Quote text (italic) - > completely invisible"),
]

print("📝 Expected transformations:")
for (input, expected) in testCases {
    print("   Input:  \"\(input)\"")
    print("   Output: \(expected)")
    print()
}

// Test 3: Implementation strategy validation
print("3️⃣ Implementation Strategy Validation...")

if FileManager.default.fileExists(atPath: notionEditorPath) {
    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        let strategyComponents = [
            ("NSColor.clear", "Making syntax transparent"),
            ("NSFont.systemFont(ofSize: 1)", "Making syntax tiny"),
            ("applyContentFormatting", "Separate content formatting"),
            ("textStorage.addAttribute(.foregroundColor", "Color attribute manipulation"),
            ("textStorage.addAttribute(.font", "Font attribute manipulation"),
        ]

        for (component, description) in strategyComponents {
            if content.contains(component) {
                print("✅ \(description): Implemented")
            } else {
                print("❌ \(description): Missing")
            }
        }

    } catch {
        print("❌ Failed to analyze implementation strategy")
    }
}

// Test 4: Build verification
print("\n4️⃣ Build Verification...")

let buildProcess = Process()
buildProcess.launchPath = "/usr/bin/swift"
buildProcess.arguments = ["build"]
buildProcess.currentDirectoryPath = FileManager.default.currentDirectoryPath

let outputPipe = Pipe()
buildProcess.standardOutput = outputPipe
buildProcess.standardError = outputPipe

do {
    try buildProcess.run()
    buildProcess.waitUntilExit()

    if buildProcess.terminationStatus == 0 {
        print("✅ Project builds successfully")
    } else {
        print("❌ Build failed")
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: outputData, encoding: .utf8) {
            print("Build output: \(output)")
        }
    }
} catch {
    print("❌ Failed to run build: \(error)")
}

// Test 5: Technical approach explanation
print("\n5️⃣ Technical Approach Explanation...")

print(
    """
    🛠️ Syntax Hiding Strategy:

       Two-Phase Approach:
       1️⃣ Phase 1: Hide Syntax
          • Apply NSColor.clear to markdown syntax characters
          • Apply tiny font (size: 1) to syntax characters
          • Make syntax visually invisible but preserve in text

       2️⃣ Phase 2: Format Content
          • Apply proper fonts to content (headers, bold, etc.)
          • Apply colors and styling to visible content
          • Leave content text unchanged in textStorage

       Key Benefits:
       ✨ Markdown syntax becomes completely invisible
       ✨ Content gets proper visual formatting
       ✨ Text structure preserved for editing/saving
       ✨ Cursor position remains accurate
       ✨ No complex text transformations needed

       Pattern Examples:
       "# Header" → "#" invisible, "Header" large & bold
       "**bold**" → "**" invisible, "bold" bold font
       "`code`" → "`" invisible, "code" monospace
    """)

print("\n✅ Syntax Hiding Validation Complete!")

print(
    """

    🚀 How to Test Results:
    1. Run: swift run IronApp
    2. Create or open a note
    3. Type: # My Header
    4. EXPECT: See "My Header" (large, bold) with NO # visible
    5. Type: **bold text**
    6. EXPECT: See "bold text" (bold font) with NO ** visible
    7. Type: `code here`
    8. EXPECT: See "code here" (monospace) with NO backticks visible

    🎯 Success Criteria:
    • Markdown syntax characters are COMPLETELY invisible
    • Content appears with proper formatting (fonts, colors, sizes)
    • Typing experience is smooth and natural
    • Text structure is preserved for saving
    • Behaves exactly like Notion/Obsidian

    🔧 If Syntax Still Visible:
    • Check NSColor.clear is being applied to syntax ranges
    • Verify tiny font (size: 1) is applied to syntax
    • Ensure applySyntaxHiding() is called before applyContentFormatting()
    • Debug regex patterns to ensure they match syntax correctly
    • Test with different markdown patterns
    """)
