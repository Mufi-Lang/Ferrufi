#!/bin/bash

# Iron Notes - No Branding Test
# Test to verify that redundant "Iron" branding has been removed for more editor space

set -e

echo "🚫 Testing Removal of Redundant Iron Branding"
echo "============================================"

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

# Create a test document for branding verification
echo "📄 Creating no-branding test document..."
cat > "$NOTES_DIR/No_Branding_Test.md" << 'EOF'
# No Branding Test

This document tests that redundant "Iron" branding has been removed to give **more space to the editor**.

## What Should Be Removed

1. ❌ **Window title "Iron"** - unnecessary since we know what app we're using
2. ❌ **Any "Iron" labels above editor** - redundant branding
3. ❌ **Extra headers or badges** - waste precious vertical space
4. ✅ **Clean, minimal interface** - focus on content, not branding

## Expected Benefits

With branding removed, we should have:

- **More vertical space** for actual content
- **Cleaner appearance** without redundant text
- **Better focus** on writing and editing
- **Professional look** without excessive self-promotion

## Test Instructions

When you open this document, check:

1. 🔍 **Window title bar** - should be clean, no "Iron" text
2. 🔍 **Above the editor** - no redundant app name display
3. 🔍 **Header area** - minimal, focused on note info
4. 🔍 **Editor space** - maximum area available for content
5. 🔍 **Overall feel** - clean, uncluttered, professional

## Content Space Test

This content should have plenty of room to breathe without UI chrome taking up space:

### Headers Should Be Prominent
# Big Header
## Medium Header
### Small Header

### Formatting Should Be Clear
**Bold text** and *italic text* should render cleanly.

`Inline code` should be easily readable.

```javascript
// Code blocks should have ample space
function noExcessiveBranding() {
    return "Focus on content, not app branding!";
}
```

### Lists Should Flow Naturally
- First item with plenty of space
- Second item without crowding
- Third item with room to read

> Quotes should also have breathing room without UI elements crowding the content area.

## Writing Experience

The editor should feel spacious and focused. Every pixel should serve the content, not remind you what app you're using. You already know you're using Iron - no need to see it everywhere!

### More Test Content

Here's a longer paragraph to test content flow. With branding removed, there should be more vertical space available for your actual writing. The interface should get out of your way and let you focus on creating great content.

The goal is **maximum content, minimal chrome, zero redundant branding**.
EOF

echo "🚀 Launching Iron Notes..."
echo ""
echo "🧹 No Branding Checklist:"
echo "   ❌ Window should NOT have 'Iron' in title bar"
echo "   ❌ Interface should NOT show redundant app branding"
echo "   ✅ Editor should have maximum vertical space available"
echo "   ✅ Interface should be clean and minimal"
echo "   ✅ Focus should be on CONTENT, not branding"
echo "   🎯 More space = better writing experience"
echo ""
echo "Open 'No_Branding_Test' and verify clean, spacious interface!"
echo "The app should be confident enough not to constantly remind you what it is."
echo ""
echo "Press Ctrl+C when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 No branding test completed!"
echo "Interface should be clean, spacious, and focused on content! 🚫🏷️"
