#!/bin/bash

# Iron Notes Compact Layout Test
# Test to verify the layout is now compact without excessive spacing

set -e

echo "📐 Testing Compact Layout"
echo "========================"

# Build the project first
echo "📦 Building Iron Notes..."
swift build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Copy test markdown to the Iron notes directory
IRON_DIR="$HOME/.iron"
NOTES_DIR="$IRON_DIR/notes"

# Ensure directories exist
mkdir -p "$NOTES_DIR"

# Create a test document for compact layout verification
echo "📄 Creating compact layout test document..."
cat > "$NOTES_DIR/Compact_Layout_Test.md" << 'EOF'
# Compact Layout Test

This document tests that Iron Notes now has a **compact, clean layout** without excessive spacing.

## What Should Be Improved

1. ✅ **Minimal toolbar** - only preview toggle and word count
2. ✅ **No "Markdown/Preview" labels** - unnecessary space wasters
3. ✅ **Compact header** - no weird badges or duplicate buttons
4. ✅ **Clean spacing** - efficient use of screen real estate
5. ✅ **More room for content** - focus on writing, not UI chrome

## Test Content

This content should have plenty of room to breathe:

**Bold text**, *italic text*, and `inline code` formatting.

```javascript
// Code blocks should be clean and compact
function compactLayout() {
    return "More space for actual content!";
}
```

### Lists Should Flow Nicely

- Item one with **bold** text
- Item two with *italic* text
- Item three with `code` text
- Item four with mixed **bold** and *italic*

> Quotes should also render cleanly without taking up excessive vertical space.

## Writing Experience

The editor should feel spacious for writing, with UI elements staying out of the way. The split view should maximize content area while keeping essential controls accessible.

### More Test Content

Here's a longer paragraph to test text flow and readability. The compact layout should make it easier to focus on your writing without UI distractions. Every pixel should serve the content, not decorative chrome.

```swift
struct CompactView: View {
    var body: some View {
        VStack(spacing: 0) { // Minimal spacing!
            ToolbarView() // Compact toolbar
            ContentArea() // Maximum content space
        }
    }
}
```

The goal is **maximum content, minimum chrome**.
EOF

echo "🚀 Launching Iron Notes..."
echo ""
echo "📏 Compact Layout Checklist:"
echo "   ✅ Header should be clean (no Split Editor badge)"
echo "   ✅ Toolbar should be minimal (just preview toggle + word count)"
echo "   ❌ NO 'Markdown' and 'Preview' labels wasting space"
echo "   ❌ NO excessive bold/italic/formatting buttons cluttering toolbar"
echo "   ✅ More vertical space for actual content"
echo "   ✅ Clean, efficient use of screen real estate"
echo ""
echo "Open 'Compact_Layout_Test' and verify the layout is now compact!"
echo "The focus should be on CONTENT, not UI chrome."
echo ""
echo "Press Ctrl+C when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 Compact layout test completed!"
echo "Layout should now be clean and space-efficient! 📐"
