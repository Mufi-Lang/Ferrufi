#!/bin/bash

# Iron Notes Clean Header Test
# Quick test to verify the header layout is clean and not weird

set -e

echo "🧹 Testing Clean Header Layout"
echo "============================="

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

# Create a simple test document to check header
echo "📄 Creating clean header test document..."
cat > "$NOTES_DIR/Clean_Header_Test.md" << 'EOF'
# Clean Header Test

This document is for testing that the header looks clean and professional.

## What to Check

The header at the top should have:

1. ✅ **Note icon and title** on the left
2. ✅ **Last modified date** below the title
3. ✅ **Word count** next to the date
4. ✅ **Theme toggle button** on the right
5. ✅ **Save, Export, and Menu buttons** on the right
6. ❌ **NO weird "Split Editor" badge**
7. ❌ **NO duplicate formatting buttons**
8. ❌ **NO conflicting toolbars**

The header should be elegant and minimal, not cluttered.

## Test Content

This is just some content to test the editor functionality:

**Bold text** and *italic text* should work.

Here's some `inline code` for testing.

```javascript
// Code block test
function cleanHeader() {
    return "Header should look professional!";
}
```

- List item 1
- List item 2
- List item 3

> This is a quote to test styling

The split editor should have its own toolbar below the header, not mixed in with the header elements.
EOF

echo "🚀 Launching Iron Notes..."
echo ""
echo "🔍 Header Inspection Checklist:"
echo "   ✅ Clean note title and icon on left"
echo "   ✅ Modification date and word count below title"
echo "   ✅ Theme toggle and action buttons on right"
echo "   ❌ NO 'Split Editor' badge or weird indicators"
echo "   ❌ NO duplicate formatting buttons in header"
echo "   🎯 Split editor toolbar should be separate below"
echo ""
echo "Open 'Clean_Header_Test' and verify the header looks clean!"
echo "Press Ctrl+C when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 Clean header test completed!"
