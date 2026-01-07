#!/bin/bash

# Iron Notes Compact Toolbar Test
# Test the new minimal toolbar with essential formatting icons

set -e

echo "🔧 Testing Compact Toolbar with Formatting Icons"
echo "==============================================="

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

# Create a test document for toolbar functionality
echo "📄 Creating compact toolbar test document..."
cat > "$NOTES_DIR/Compact_Toolbar_Test.md" << 'EOF'
# Compact Toolbar Test

This document tests the new **compact toolbar** with essential formatting icons.

## Toolbar Features

The toolbar should have these **compact icon buttons**:

1. 👁️ **Preview Toggle** - show/hide preview pane
2. **B** **Bold** - add **bold** formatting
3. *I* **Italic** - add *italic* formatting
4. `<>` **Code** - add `inline code` formatting
5. **#** **Header** - add header formatting
6. **•** **List** - add bullet list items
7. **{}** **Code Block** - add code blocks
8. 📊 **Word Count** - display word count

## Test Instructions

Try clicking each toolbar button to test functionality:

### Bold Button Test
Click the **B** button to wrap text in **bold** formatting.

### Italic Button Test
Click the *I* button to wrap text in *italic* formatting.

### Code Button Test
Click the `<>` button to add `inline code` formatting.

### Header Button Test
Click the **#** button to add:
# New header line

### List Button Test
Click the **•** button to add:
- New list item

### Code Block Button Test
Click the **{}** button to add:
```
New code block
```

## Expected Layout

The toolbar should be:
- ✅ **Compact** - minimal height and padding
- ✅ **Icon-based** - clear, recognizable symbols
- ✅ **Functional** - each button works correctly
- ✅ **Efficient** - no wasted space
- ✅ **Professional** - clean appearance

## Test Content for Formatting

Here's some text you can select and format using the toolbar:

This text can be made bold.
This text can be made italic.
This text can be made into code.
This text can be made into a header.
This text can be made into a list item.

## Toolbar Button Reference

| Icon | Function | Shortcut | Result |
|------|----------|----------|---------|
| 👁️ | Toggle Preview | Click | Show/Hide right pane |
| **B** | Bold | Click | **text** |
| *I* | Italic | Click | *text* |
| `<>` | Inline Code | Click | `text` |
| **#** | Header | Click | # text |
| **•** | List | Click | - text |
| **{}** | Code Block | Click | ```\ntext\n``` |

The toolbar should feel natural and responsive while staying out of your way!
EOF

echo "🚀 Launching Iron Notes..."
echo ""
echo "🧪 Compact Toolbar Test Checklist:"
echo "   ✅ Toolbar should be compact (minimal height)"
echo "   ✅ Icons should be clear and recognizable"
echo "   ✅ Preview toggle button should work"
echo "   ✅ Bold button should add ** formatting"
echo "   ✅ Italic button should add * formatting"
echo "   ✅ Code button should add \` formatting"
echo "   ✅ Header button should add # formatting"
echo "   ✅ List button should add - formatting"
echo "   ✅ Code block button should add \`\`\` formatting"
echo "   ✅ Word count should update as you type"
echo "   ✅ Buttons should have helpful tooltips"
echo ""
echo "Open 'Compact_Toolbar_Test' and test each toolbar button!"
echo "The toolbar should be functional but unobtrusive."
echo ""
echo "Press Ctrl+C when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 Compact toolbar test completed!"
echo "Toolbar should be compact yet fully functional! 🔧✨"
