#!/bin/bash

# Iron App Test Runner
# This script builds and runs the Iron app to test the improved vault picker

set -e

echo "🔨 Building Iron..."
swift build

echo "🚀 Launching Iron..."
echo "Testing the improved vault picker interface..."
echo ""
echo "What to test:"
echo "1. ✓ Vault naming - Click 'Create' tab and try typing a vault name"
echo "2. ✓ App termination - Close the vault picker to quit the app"
echo "3. ✓ Recent vaults - Any created vaults should appear in 'Recent' tab"
echo "4. ✓ Browse functionality - Use 'Browse' tab to select existing folders"
echo "5. ✓ Validation feedback - Try invalid names to see validation messages"
echo ""

# Run the app
./.build/debug/IronApp

echo ""
echo "✅ Iron app session ended"
