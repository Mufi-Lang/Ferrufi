#!/bin/bash

# Iron Notes Code Block Styling Test
# This script launches Iron with a test document to showcase improved code block styling

set -e

echo "🎨 Testing Iron Notes Code Block Styling"
echo "======================================="

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

# Copy our test file
echo "📄 Creating test document with code blocks..."
cp "test_code_blocks.md" "$NOTES_DIR/Code_Block_Styling_Test.md"

echo "🚀 Launching Iron Notes..."
echo ""
echo "📝 Instructions:"
echo "   1. Iron will open with your notes"
echo "   2. Open 'Code_Block_Styling_Test' from the sidebar"
echo "   3. Test the improved code block styling:"
echo "      • Code blocks should have rounded backgrounds"
echo "      • Syntax markers (```) should be hidden"
echo "      • Code should use monospace font"
echo "      • Different languages should be detected"
echo "      • Proper spacing and padding around blocks"
echo ""
echo "Press Ctrl+C to stop Iron when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 Code block styling test completed!"
