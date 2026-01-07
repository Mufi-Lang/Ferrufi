#!/bin/bash

# Iron App - Vault Picker TextField Test Script
# Tests the new WorkingVaultPicker to verify TextField functionality

set -e

echo "🧪 Iron Vault Picker TextField Test"
echo "==================================="
echo ""

# Build first
echo "🔨 Building Iron..."
swift build

echo ""
echo "🚀 Launching Iron with WorkingVaultPicker..."
echo ""
echo "TEST INSTRUCTIONS:"
echo "=================="
echo ""
echo "1. ✅ VAULT NAMING TEST:"
echo "   - Click the 'Create' tab"
echo "   - Try typing in the vault name field"
echo "   - You should see the text appear as you type"
echo "   - Debug messages will show in console"
echo ""
echo "2. ✅ VALIDATION TEST:"
echo "   - Try different vault names"
echo "   - See validation feedback (green checkmark vs orange warning)"
echo "   - Try invalid characters like / or \\"
echo ""
echo "3. ✅ APP TERMINATION TEST:"
echo "   - Click Cancel or the X button"
echo "   - App should quit properly"
echo "   - No hanging processes"
echo ""
echo "4. ✅ FOCUS TEST:"
echo "   - When switching to Create mode, name field should auto-focus"
echo "   - You should be able to immediately start typing"
echo ""
echo "5. ✅ FUNCTIONALITY TEST:"
echo "   - Fill in vault name and location"
echo "   - Click 'Create Vault'"
echo "   - Should create actual vault and open Iron"
echo ""

echo "Press Ctrl+C to stop the test when done."
echo ""
echo "DEBUG OUTPUT:"
echo "============="

# Run with debug output highlighting
./.build/debug/IronApp 2>&1 | while IFS= read -r line; do
    case "$line" in
        *"Vault name changed"*|*"TextField changed"*|*"DEBUG"*)
            echo "🔍 TEXTFIELD: $line"
            ;;
        *"Error"*|*"Failed"*)
            echo "❌ ERROR: $line"
            ;;
        *"WorkingVaultPicker"*|*"appeared"*)
            echo "ℹ️  UI: $line"
            ;;
        *)
            echo "$line"
            ;;
    esac
done

echo ""
echo "✅ Test completed!"
echo ""
echo "EXPECTED RESULTS:"
echo "================"
echo "✓ TextField should be immediately editable"
echo "✓ Typing should show debug messages in console"
echo "✓ Validation should provide real-time feedback"
echo "✓ App should quit cleanly when closed"
echo "✓ Vault creation should work end-to-end"
echo ""
echo "If any of these fail, there may be remaining issues to fix."
