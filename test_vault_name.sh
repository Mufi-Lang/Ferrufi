#!/bin/bash

# Test script for Iron's simplified ~/.iron storage system
# Tests the new single-directory approach without vault management

echo "🧪 Testing Iron Simplified Storage System"
echo "========================================"
echo ""

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Please run this script from the Iron project root directory"
    exit 1
fi

# Show current ~/.iron structure if it exists
echo "📁 Current ~/.iron directory structure:"
if [ -d "$HOME/.iron" ]; then
    echo "   ~/.iron exists - showing current structure:"
    echo ""

    if [ -f "$HOME/.iron/config.json" ]; then
        echo "   ✅ config.json exists"
    else
        echo "   ℹ️  config.json not yet created"
    fi

    if [ -d "$HOME/.iron/notes" ]; then
        note_count=$(find "$HOME/.iron/notes" -name "*.md" -type f 2>/dev/null | wc -l)
        echo "   ✅ notes/ directory exists with $note_count markdown file(s)"

        if [ -f "$HOME/.iron/notes/Welcome.md" ]; then
            echo "   ✅ Welcome.md exists"
        else
            echo "   ℹ️  Welcome.md not yet created"
        fi
    else
        echo "   ℹ️  notes/ directory not yet created"
    fi
else
    echo "   ~/.iron does not exist yet (will be created on first run)"
fi

echo ""
echo "🎯 Test Scenarios:"
echo "=================="
echo "1. 🚀 Direct app startup:"
echo "   - Iron launches directly to main interface"
echo "   - No vault picker or selection screens"
echo "   - ~/.iron/notes/ directory created automatically"
echo "   - Welcome.md generated on first run"
echo ""

echo "2. 📝 Note management:"
echo "   - All notes stored in ~/.iron/notes/"
echo "   - Can create subfolders for organization"
echo "   - Search works across all notes"
echo "   - No vault switching needed"
echo ""

echo "3. ⚙️  Configuration:"
echo "   - Settings stored in ~/.iron/config.json"
echo "   - Default configuration applied automatically"
echo "   - No vault-specific configuration needed"
echo ""

echo "✅ What to verify:"
echo "===================="
echo "• App launches directly without any picker screens"
echo "• ~/.iron/notes/ directory is created automatically"
echo "• Welcome.md appears in notes directory"
echo "• Main interface shows note list immediately"
echo "• Can create and edit notes without setup"
echo "• Configuration file is generated automatically"
echo "• No vault-related UI or concepts visible"
echo ""

echo "🐛 Debug features:"
echo "=================="
echo "• Console shows 'Iron directory structure created at: ~/.iron'"
echo "• Welcome note creation logged if generated"
echo "• File operations logged for debugging"
echo "• Configuration loading/saving messages"
echo ""

# Check for common issues
echo "⚠️  Pre-flight checks:"
echo "======================"

# Check write permissions to home directory
if [ ! -w "$HOME" ]; then
    echo "❌ Warning: No write permission to home directory"
else
    echo "✅ Home directory is writable"
fi

# Check if ~/.iron exists and is writable
if [ -d "$HOME/.iron" ]; then
    if [ ! -w "$HOME/.iron" ]; then
        echo "❌ Warning: ~/.iron exists but is not writable"
    else
        echo "✅ ~/.iron directory is accessible"
    fi
fi

# Check for disk space
available_space=$(df -h "$HOME" | awk 'NR==2 {print $4}')
echo "💾 Available disk space: $available_space"

# Check if there are any old vault directories that might cause confusion
if [ -d "$HOME/.iron/vaults" ]; then
    echo "⚠️  Old vault structure detected at ~/.iron/vaults/"
    echo "   This won't interfere with the new system, but you may want to migrate notes manually"
fi

echo ""
read -p "Press Enter to start Iron and begin testing (Ctrl+C to cancel)..."

echo ""
echo "🚀 Starting Iron app..."
echo "📝 Watch console output for initialization messages..."
echo ""
echo "Expected console messages:"
echo "• 'Iron directory structure created at: ~/.iron'"
echo "• 'Created welcome note at: ~/.iron/notes/Welcome.md'"
echo "• 'Initialized with notes directory: ~/.iron/notes'"
echo ""

# Function to show live directory monitoring
monitor_iron_directory() {
    if command -v fswatch >/dev/null 2>&1; then
        echo "📊 Monitoring ~/.iron directory changes (in background)..."
        fswatch -o "$HOME/.iron" 2>/dev/null | while read num; do
            echo "$(date '+%H:%M:%S') | ~/.iron directory changed"
        done &
        FSWATCH_PID=$!
    fi
}

# Start directory monitoring if available
monitor_iron_directory

# Build and run with timestamped output
echo "Building and running Iron..."
swift run IronApp 2>&1 | while IFS= read -r line; do
    echo "$(date '+%H:%M:%S') | $line"
done

# Cleanup background processes
if [ ! -z "$FSWATCH_PID" ]; then
    kill $FSWATCH_PID 2>/dev/null
fi

echo ""
echo "🔍 Post-run verification:"
echo "========================="

if [ -d "$HOME/.iron" ]; then
    echo "✅ ~/.iron directory was created"

    if [ -d "$HOME/.iron/notes" ]; then
        echo "✅ ~/.iron/notes directory exists"

        note_count=$(find "$HOME/.iron/notes" -name "*.md" -type f 2>/dev/null | wc -l)
        if [ $note_count -gt 0 ]; then
            echo "✅ Found $note_count markdown file(s):"
            find "$HOME/.iron/notes" -name "*.md" -type f | while read note_file; do
                note_name=$(basename "$note_file")
                echo "   📄 $note_name"
            done
        else
            echo "ℹ️  No markdown files found (normal if app was closed quickly)"
        fi

        if [ -f "$HOME/.iron/notes/Welcome.md" ]; then
            echo "✅ Welcome.md was created"

            # Check if welcome note has expected content
            if grep -q "Welcome to Iron!" "$HOME/.iron/notes/Welcome.md" 2>/dev/null; then
                echo "   ✅ Welcome note has correct content"
            else
                echo "   ⚠️  Welcome note exists but content may be incomplete"
            fi
        else
            echo "❌ Welcome.md was not created"
        fi
    else
        echo "❌ ~/.iron/notes directory was not created"
    fi

    if [ -f "$HOME/.iron/config.json" ]; then
        echo "✅ config.json exists"

        # Validate JSON syntax
        if python3 -m json.tool "$HOME/.iron/config.json" >/dev/null 2>&1; then
            echo "   ✅ Configuration file has valid JSON syntax"
        else
            echo "   ⚠️  Configuration file may have syntax issues"
        fi
    else
        echo "ℹ️  config.json not yet created (normal for quick app launches)"
    fi
else
    echo "❌ ~/.iron directory was not created"
fi

# Check if any old vault picker UI appeared (shouldn't happen)
echo ""
echo "🎯 Simplified system verification:"
echo "=================================="
echo "• Did Iron launch directly to the main interface? (Should be YES)"
echo "• Was there any vault picker or selection screen? (Should be NO)"
echo "• Could you see the note list immediately? (Should be YES)"
echo "• Are all notes stored in ~/.iron/notes/? (Should be YES)"

echo ""
echo "🏁 Test completed!"
echo ""
echo "💡 Tips for verification:"
echo "• Check that Iron opened directly without any setup screens"
echo "• Verify main interface appeared immediately"
echo "• Confirm ~/.iron/notes/ contains your markdown files"
echo "• Test creating a new note - it should appear in ~/.iron/notes/"
echo "• Search should work across all notes in the directory"
echo ""
echo "🔄 To test again:"
echo "• You can delete ~/.iron directory and re-run to test fresh installation"
echo "• Or just run 'swift run IronApp' to test normal startup"
