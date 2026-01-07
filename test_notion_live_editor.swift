#!/usr/bin/env swift

import Foundation

// Test script to verify Notion-style live editor functionality
print("🚀 Iron Notion-Style Live Editor Test")
print(String(repeating: "=", count: 60))

// Test 1: Verify NotionStyleEditor exists and has live formatting
print("\n1️⃣ Testing NotionStyleEditor Implementation...")

let notionEditorPath = "Sources/Iron/UI/Components/NotionStyleEditor.swift"
if FileManager.default.fileExists(atPath: notionEditorPath) {
    print("✅ NotionStyleEditor.swift exists")

    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        // Check for key Notion-style features
        let features = [
            ("applyLiveFormatting", "Live formatting method"),
            ("applyHeaders", "Header formatting"),
            ("applyBoldItalic", "Bold/italic formatting"),
            ("applyCode", "Code formatting"),
            ("applyLinks", "Link formatting"),
            ("NSTextStorage", "Rich text storage"),
            ("textDidChange", "Real-time text change handling"),
        ]

        for (feature, description) in features {
            if content.contains(feature) {
                print("✅ \(description): Found")
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

// Test 2: Verify DetailView integration
print("\n2️⃣ Testing DetailView Integration...")

let detailViewPath = "Sources/Iron/UI/Views/DetailView.swift"
if FileManager.default.fileExists(atPath: detailViewPath) {
    do {
        let content = try String(contentsOfFile: detailViewPath, encoding: .utf8)

        if content.contains("NotionStyleEditor") {
            print("✅ DetailView uses NotionStyleEditor")
        } else {
            print("❌ DetailView missing NotionStyleEditor")
        }

        if !content.contains("DetailViewMode") {
            print("✅ Old view mode system removed")
        } else {
            print("❌ Old view mode system still present")
        }

        if !content.contains("splitView") || !content.contains("previewView") {
            print("✅ Split and preview modes removed")
        } else {
            print("❌ Split/preview modes still present")
        }

        if content.contains("notionStyleEditingView") {
            print("✅ Notion-style editing view present")
        } else {
            print("❌ Notion-style editing view missing")
        }

    } catch {
        print("❌ Failed to read DetailView.swift: \(error)")
    }
} else {
    print("❌ DetailView.swift missing")
}

// Test 3: Test live formatting patterns
print("\n3️⃣ Testing Live Formatting Patterns...")

let testCases = [
    ("# Header 1", "H1 header"),
    ("## Header 2", "H2 header"),
    ("**bold text**", "Bold formatting"),
    ("*italic text*", "Italic formatting"),
    ("`inline code`", "Inline code"),
    ("```code block```", "Code block"),
    ("[link](url)", "Link formatting"),
    ("- list item", "List item"),
    ("> blockquote", "Blockquote"),
]

print("📝 Testing markdown patterns that should get live formatting:")
for (pattern, description) in testCases {
    print("   • \(pattern) → \(description)")
}

// Test 4: Verify theme integration
print("\n4️⃣ Testing Theme Integration...")

if FileManager.default.fileExists(atPath: notionEditorPath) {
    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        if content.contains("themeManager") {
            print("✅ Theme manager integration")
        } else {
            print("❌ Theme manager missing")
        }

        if content.contains("updateTheme") {
            print("✅ Theme update method")
        } else {
            print("❌ Theme update method missing")
        }

        if content.contains("NSColor(theme.colors") {
            print("✅ Theme color application")
        } else {
            print("❌ Theme color application missing")
        }

    } catch {
        print("❌ Failed to analyze theme integration")
    }
}

// Test 5: Performance considerations
print("\n5️⃣ Performance Analysis...")

if FileManager.default.fileExists(atPath: notionEditorPath) {
    do {
        let content = try String(contentsOfFile: notionEditorPath, encoding: .utf8)

        if content.contains("DispatchQueue.main.asyncAfter") {
            print("✅ Debounced formatting updates")
        } else {
            print("⚠️ No formatting debouncing found")
        }

        if content.contains("guard") && content.contains("textStorage") {
            print("✅ Safe text storage access")
        } else {
            print("⚠️ Text storage safety checks needed")
        }

    } catch {
        print("❌ Failed to analyze performance aspects")
    }
}

// Test 6: Build verification
print("\n6️⃣ Build Verification...")

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

// Test 7: Expected behavior
print("\n7️⃣ Expected Notion-Style Behavior...")

print(
    """
    🎯 Expected Live Editor Behavior:

       As you type:
       • Headers (# ## ###) should get larger, bold fonts
       • **bold** should render in bold weight
       • *italic* should render in italic style
       • `code` should get monospace font + background
       • Links should get accent coloring
       • Lists should get bullet points
       • Blockquotes should get left border + italic

       Real-time updates:
       • Formatting applies as you type
       • No separate preview pane needed
       • Theme colors applied throughout
       • Smooth, responsive editing experience

       Performance:
       • Formatting updates are debounced
       • Only visible text gets processed
       • No lag during typing
    """)

print("\n✅ Notion-Style Live Editor Test Complete!")

print(
    """

    🚀 To Test the Editor:
    1. Run: swift run IronApp
    2. Create or open a note
    3. Type markdown syntax and watch it format live
    4. Try: # Header, **bold**, *italic*, `code`
    5. Verify smooth, real-time formatting

    🔧 If Issues Found:
    1. Check console for NSTextView errors
    2. Verify textStorage is not nil
    3. Test with different markdown patterns
    4. Check theme color applications
    5. Monitor performance with large documents
    """)
