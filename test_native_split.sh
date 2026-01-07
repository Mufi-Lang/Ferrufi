#!/bin/bash

# Iron Notes Native Split Editor Test
# This script launches Iron with the new native split editor (no HTML!)

set -e

echo "🎨 Testing Iron Notes Native Split Editor"
echo "========================================"

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

# Create a comprehensive test document
echo "📄 Creating native split editor test document..."
cat > "$NOTES_DIR/Native_Split_Editor_Test.md" << 'EOF'
# Native Split Editor Test

This document tests the **native SwiftUI split editor** with live preview (no HTML rendering!).

## Features

- ✅ **Native SwiftUI** rendering
- ✅ **Split pane** layout
- ✅ **Live preview** without HTML
- ✅ **Plain text editor** with syntax highlighting
- ✅ **Real-time** markdown parsing

## Markdown Elements

### Headers
Different header levels should render properly:

# Header 1
## Header 2
### Header 3

### Text Formatting

Here's some **bold text** and *italic text* mixed together.

You can also have `inline code` within paragraphs.

### Lists

Bullet lists should work:
- First item
- Second item
- Third item with **bold** text
- Fourth item with *italic* text

### Code Blocks

Plain code block:
```
function simpleExample() {
    return "no language specified";
}
```

Swift code block:
```swift
struct ContentView: View {
    @State private var text = "Hello, World!"

    var body: some View {
        VStack {
            Text(text)
                .font(.title)

            TextField("Enter text", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
}
```

JavaScript code block:
```javascript
class NativeSplitEditor {
    constructor(options = {}) {
        this.markdown = options.markdown || '';
        this.preview = options.preview || true;
    }

    render() {
        // Native SwiftUI rendering - no HTML needed!
        return this.parseMarkdown(this.markdown);
    }
}
```

### Quotes

> This is a blockquote that should be nicely styled
> with proper indentation and formatting.

> Another quote with **bold** and *italic* text inside.

### Mixed Content

Here's a paragraph with `inline code`, **bold text**, and *italic text* all mixed together. The native renderer should handle this gracefully.

## Performance Benefits

The native split editor offers several advantages:

1. **No HTML conversion** - faster rendering
2. **Native SwiftUI** - better integration
3. **Real-time updates** - instant preview
4. **Memory efficient** - no WebView overhead
5. **Theme integration** - perfect color matching

## Test Instructions

When you open this document:

1. **Left pane** should show raw markdown with syntax highlighting
2. **Right pane** should show native SwiftUI rendered preview
3. **Toolbar** should have formatting buttons
4. **Live updates** - changes in left pane appear instantly in right pane
5. **Split ratio** should be adjustable by dragging the divider
6. **Toggle preview** button should hide/show the right pane

## Code Block Languages

Test different language detection:

Python:
```python
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)

# Test with emoji and unicode
print("🚀 Native rendering works! ✨")
```

Bash:
```bash
#!/bin/bash
echo "Testing native split editor"
for i in {1..5}; do
    echo "Line $i"
done
```

JSON:
```json
{
    "name": "Iron Notes",
    "version": "1.0.0",
    "features": [
        "Native split editor",
        "No HTML rendering",
        "SwiftUI preview",
        "Real-time updates"
    ],
    "performance": "🚀 Fast!"
}
```

---

**Note**: This test document should render beautifully in the native split editor without any HTML conversion!
EOF

echo "🚀 Launching Iron Notes with Native Split Editor..."
echo ""
echo "📝 Test Instructions:"
echo "   1. Iron will open with your notes"
echo "   2. Open 'Native_Split_Editor_Test' from the sidebar"
echo "   3. You should see a split view:"
echo "      • Left: Raw markdown editor"
echo "      • Right: Native SwiftUI preview"
echo "   4. Test editing in the left pane"
echo "   5. Watch the right pane update in real-time"
echo "   6. Try the formatting toolbar buttons"
echo "   7. Toggle the preview with the sidebar button"
echo ""
echo "Press Ctrl+C to stop Iron when done testing..."
echo ""

# Launch Iron
swift run IronApp

echo ""
echo "🎉 Native split editor test completed!"
echo "No HTML rendering needed - pure SwiftUI! ✨"
