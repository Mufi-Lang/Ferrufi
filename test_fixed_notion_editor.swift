#!/usr/bin/env swift

import Foundation

// Test script for fixed Notion-style attribute-based rendering in Iron
print("🎯 Iron Fixed Notion-Style Editor Test")
print(String(repeating: "=", count: 60))

// Test 1: Verify attribute-based rendering implementation
print("\n1️⃣ Testing Attribute-Based Rendering...")

let notionEditorPath = "Sources/Iron/UI/Components/NotionStyleEditor.swift"
if FileManager.default.fileExists(atPath: notionEditorPath) {
    print("✅ NotionStyleEditor.swift exists")

    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        // Check for proper attribute-based implementation
        let attributeFeatures = [
            ("applyNotionFormatting()", "Main formatting method"),
            ("textStorage.addAttribute", "NSTextStorage attribute manipulation"),
            ("hideMarkdownSyntax", "Syntax hiding method"),
            ("selectedRange()", "Cursor position preservation"),
            ("isApplyingFormatting", "Formatting lock to prevent conflicts"),
            ("applyHeaderFormatting", "Header attribute styling"),
            ("applyBoldItalicFormatting", "Bold/italic attribute styling"),
            ("applyCodeFormatting", "Code attribute styling"),
        ]

        for (feature, description) in attributeFeatures {
            if content.contains(feature) {
                print("✅ \(description): Found")
            } else {
                print("❌ \(description): Missing")
            }
        }

        // Check that we're NOT transforming text content
        let badPatterns = [
            ("renderMarkdownToDisplay", "Text content transformation (BAD)"),
            ("transformHeaders", "Text transformation (BAD)"),
            ("mutableString.setString", "Text replacement (BAD)"),
            ("replacingOccurrences", "String replacement (BAD)"),
        ]

        for (pattern, description) in badPatterns {
            if content.contains(pattern) {
                print("❌ \(description): Found (this breaks editing)")
            } else {
                print("✅ \(description): Not found (good)")
            }
        }

    } catch {
        print("❌ Failed to read NotionStyleEditor.swift: \(error)")
    }
} else {
    print("❌ NotionStyleEditor.swift missing")
}

// Test 2: Expected Notion-style behavior
print("\n2️⃣ Expected Notion-Style Behavior...")

print(
    """
    🎯 Proper Notion-Style Behavior:

       Text Content (unchanged):    Visual Appearance:
       # Big Header                Big Header (large, bold font)
       **bold text**               bold text (bold weight)
       *italic text*               italic text (italic style)
       `inline code`               inline code (monospace, background)
       [Link](url)                 Link (colored, underlined)
       - List item                 - List item (colored bullet)
       > Quote text                Quote text (italic, muted)

       Key Principles:
       ✨ Text content NEVER changes - only visual attributes
       ✨ Markdown syntax stays in text but gets styled differently
       ✨ Content text gets enhanced formatting (bold, large, etc.)
       ✨ Syntax characters get dimmed/hidden styling
       ✨ Typing experience is smooth and uninterrupted
       ✨ Cursor position is preserved during formatting
    """)

// Test 3: Build verification
print("\n3️⃣ Build Verification...")

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

// Test 4: Implementation validation
print("\n4️⃣ Implementation Validation...")

if FileManager.default.fileExists(atPath: notionEditorPath) {
    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        // Check for safe editing practices
        let safePatterns = [
            ("selectedRange = self.selectedRange()", "Cursor position preservation"),
            ("setSelectedRange(selectedRange)", "Cursor position restoration"),
            ("isApplyingFormatting = true", "Formatting conflict prevention"),
            ("!isApplyingFormatting", "Formatting guard check"),
            ("textStorage.addAttribute(.font", "Safe attribute application"),
        ]

        for (pattern, description) in safePatterns {
            if content.contains(pattern) {
                print("✅ \(description): Implemented")
            } else {
                print("⚠️ \(description): Check implementation")
            }
        }

        // Check for performance optimizations
        if content.contains("DispatchQueue.main.asyncAfter") {
            print("✅ Debounced formatting updates")
        } else {
            print("⚠️ Consider adding debounced updates")
        }

    } catch {
        print("❌ Failed to validate implementation")
    }
}

print("\n✅ Fixed Notion-Style Editor Test Complete!")

print(
    """

    🚀 How to Test the Fixed Editor:
    1. Run: swift run IronApp
    2. Create or open a note
    3. Type: # My Header
    4. See: "# My Header" text with large bold formatting on "My Header"
    5. Type: This is **bold** text
    6. See: "This is **bold** text" with bold formatting on "bold"
    7. Type: Here's `some code`
    8. See: "Here's `some code`" with monospace formatting on "some code"

    🔍 What Should Happen:
    • Text content never disappears or changes
    • Only visual formatting (fonts, colors, sizes) applied
    • Markdown syntax stays but gets dimmed/styled
    • Content gets enhanced visual appearance
    • Typing is smooth with no interruptions
    • Cursor stays in correct position

    🔧 Key Differences from Broken Version:
    • NO text content transformation
    • NO string replacement operations
    • NO content disappearing while typing
    • YES attribute-based visual styling only
    • YES smooth, uninterrupted editing experience
    • YES proper Notion-like appearance
    """)
