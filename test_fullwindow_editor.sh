#!/bin/bash

# Iron Notes Full Window Editor Test
# Test the new full-window editor that extends into the title bar area

set -e

echo "🖥️  Testing Full Window Editor with Sidebar Branding"
echo "==================================================="

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

# Create a test document for full-window testing
echo "📄 Creating full-window editor test document..."
cat > "$NOTES_DIR/Full_Window_Editor_Test.md" << 'EOF'
# Full Window Editor Test

This document tests the **full-window editor** that extends into the title bar area for maximum content space.

## What Should Be Different

1. ✅ **Editor fills entire window** - including title bar area
2. ✅ **No wasted title bar space** - content extends to window edges
3. ✅ **"Iron" branding in sidebar** - next to brain logo where it belongs
4. ✅ **Maximum content area** - every pixel used for your writing
5. ✅ **Immersive experience** - no OS chrome interrupting your flow

## Expected Layout

### Window Properties
- **Borderless content area** - editor extends to window edges
- **Transparent title bar** - content flows underneath
- **Full-size content view** - maximum screen real estate
- **Hidden window title** - no redundant text in title bar

### Sidebar Layout
- **Brain icon** + **"Iron"** text - proper branding placement
- **"Knowledge System"** subtitle - clear app identity
- **Theme toggle** - easy access to appearance settings
- **Navigation elements** - folders, notes, search

### Editor Area
- **Split view editor** - markdown + live preview
- **Compact toolbar** - formatting tools without clutter
- **Maximum content height** - extends to very top of window
- **Seamless experience** - no gaps or wasted space

## Content Space Test

With the full-window editor, this content should have maximum vertical space:

### Headers Get More Room
# Big Header - Should Feel Spacious
## Medium Header - More Breathing Room
### Small Header - Comfortable Spacing

### Code Blocks Have Space to Shine
```javascript
// This code block should have plenty of vertical space
// No title bar wasting precious real estate
function fullWindowExperience() {
    return {
        contentArea: "maximized",
        distractions: "minimized",
        focus: "enhanced",
        productivity: "boosted"
    };
}
```

### Lists Flow Naturally
- First item with generous spacing above and below
- Second item without feeling cramped
- Third item with room to breathe
- Fourth item enjoying the extra vertical space

### Quotes Have Breathing Room
> This quote should feel spacious and comfortable, not cramped by UI chrome taking up precious vertical space at the top of the window.

## Writing Experience

The full-window editor should create an immersive writing environment where:

- **Content is king** - maximum space for your thoughts
- **UI gets out of the way** - minimal chrome, maximum content
- **Vertical space is maximized** - title bar area reclaimed for content
- **Distraction-free** - seamless edge-to-edge content area

### Performance Expectations

With the window modifications:
- ✅ Window should open without title bar chrome
- ✅ Content should extend to window edges
- ✅ Editor should feel spacious and immersive
- ✅ Sidebar should show "Iron" branding clearly
- ✅ Overall experience should feel premium and focused

## Test Instructions

When you open this document:

1. 🔍 **Check window edges** - content should extend to very top
2. 🔍 **Verify sidebar branding** - "Iron" should be visible next to brain
3. 🔍 **Test content area** - should feel spacious and immersive
4. 🔍 **Confirm no title bar** - no OS chrome wasting space
5. 🔍 **Editor experience** - maximum vertical real estate

The goal is **immersive, distraction-free writing** with every pixel serving your content!
EOF

echo "🚀 Launching Iron Notes with Full Window Editor..."
echo ""
echo "🖥️  Full Window Test Checklist:"
echo "   ✅ Window should have no visible title bar chrome"
echo "   ✅ Content should extend to the very top of window"
echo "   ✅ Editor should feel immersive and spacious"
echo "   ✅ Sidebar should show 'Iron' text next to brain logo"
echo "   ✅ Maximum vertical space for content writing"
echo "   ✅ Seamless, distraction-free editing experience"
echo ""
echo "Open 'Full_Window_Editor_Test' and enjoy the spacious editor!"
echo "The editor should now use every pixel for your content."
echo ""
echo "Press Ctrl+C when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 Full window editor test completed!"
echo "Editor should now be immersive and use maximum screen space! 🖥️✨"
