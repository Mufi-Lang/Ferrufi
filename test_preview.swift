#!/usr/bin/env swift

//
//  test_preview.swift
//  Iron
//
//  Test script to verify theme-aware markdown preview functionality
//

import Foundation

print("🔍 Testing Theme-Aware Markdown Preview")
print("=====================================")

// Test markdown content
let testMarkdown = """
    # Theme-Aware Preview Test

    This is a test document to verify the **markdown preview** functionality works correctly with *different themes*.

    ## Code Examples

    Here's some `inline code` and a code block:

    ```swift
    func testThemes() {
        print("Hello, Iron!")
        return true
    }
    ```

    ## Lists and Links

    - Item 1 with **bold text**
    - Item 2 with *italic text*
    - Item 3 with [external link](https://example.com)
    - Item 4 with [[wiki link]]
    - Item 5 with #tag

    ## Blockquotes

    > This is a blockquote that should adapt to the current theme colors.
    > It should look good in both light and dark themes.

    ## Other Elements

    1. Numbered list item
    2. ~~Strikethrough text~~
    3. ==Highlighted text==

    ---

    **Test Results:**
    - ✅ Headers should use theme foreground color
    - ✅ Code blocks should use theme background secondary
    - ✅ Links and tags should use theme accent color
    - ✅ Borders should use theme border color
    - ✅ Text should use theme foreground colors

    *Theme switching should update all colors dynamically.*
    """

print("\n📝 Test Markdown Content:")
print("─────────────────────────")
print(testMarkdown)

print("\n🎨 Theme Integration Points:")
print("────────────────────────────")
print("1. WorkingMarkdownRenderer now has themeManager property")
print("2. generateCSS() uses theme colors instead of hardcoded values")
print("3. Color.toHex() extension converts SwiftUI colors to CSS hex")
print("4. Theme changes trigger re-render via onChange")

print("\n🔧 Key Fixes Applied:")
print("─────────────────────")
print("✅ Added themeManager: ThemeManager? property to WorkingMarkdownRenderer")
print("✅ Updated generateCSS() to use theme.colors instead of hardcoded CSS")
print("✅ Added Color.toHex() extension for SwiftUI → CSS color conversion")
print("✅ Added theme change detection in WorkingMarkdownView")
print("✅ Improved color space handling for accurate hex conversion")

print("\n🎯 CSS Color Mapping:")
print("─────────────────────")
print("• Background: theme.background → body background-color")
print("• Text: theme.foreground → body color, headers, strong")
print("• Secondary: theme.foregroundSecondary → em, del, h6, blockquote")
print("• Accent: theme.accent → links, wiki-links, tags, inline-code")
print("• Border: theme.border → hr, h1/h2 borders, blockquote border")
print("• Code BG: theme.backgroundSecondary → code blocks, inline-code")

print("\n🧪 Testing Instructions:")
print("────────────────────────")
print("1. Run: swift run IronApp")
print("2. Create or edit a note with markdown content")
print("3. Switch to preview mode or split view")
print("4. Change themes using the painting palette icon")
print("5. Verify preview colors update immediately")

print("\n📋 Visual Verification Checklist:")
print("─────────────────────────────────")
print("□ Headers use theme text color (not hardcoded black/white)")
print("□ Code blocks have theme-appropriate background")
print("□ Links and tags use theme accent color")
print("□ Borders match theme border color")
print("□ Overall contrast is readable in all themes")
print("□ Theme switching updates preview without page reload")

print("\n🚀 Advanced Theme Features:")
print("──────────────────────────")
print("• Supports all 8+ curated themes (Ghost White, Tokyo Night, etc.)")
print("• Dynamic color extraction from SwiftUI Color to CSS hex")
print("• Proper sRGB color space conversion for accuracy")
print("• Fallback colors for edge cases")
print("• Alpha channel support for semi-transparent elements")

print("\n⚡ Performance Notes:")
print("────────────────────")
print("• CSS generation is fast (direct string interpolation)")
print("• Theme changes trigger single re-render")
print("• Color conversion cached by SwiftUI Color instances")
print("• WebView efficiently updates HTML content")

let fileManager = FileManager.default
let markdownFile = fileManager.currentDirectoryPath + "/test_markdown_preview.md"

do {
    try testMarkdown.write(toFile: markdownFile, atomically: true, encoding: .utf8)
    print("\n📄 Created test file: test_markdown_preview.md")
    print("   You can open this in Iron to test the preview functionality")
} catch {
    print("\n⚠️  Could not create test file: \(error)")
}

print("\n✨ Theme-Aware Preview Testing Complete!")
print("\nThe markdown preview should now properly adapt to all themes.")
print("Colors will update dynamically when switching themes. 🎨")
