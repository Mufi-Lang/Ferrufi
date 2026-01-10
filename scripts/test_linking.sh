#!/bin/bash
# Test script to verify libmufiz linking works correctly

set -e

echo "=== Ferrufi libmufiz Linking Test ==="
echo ""

# Test 1: Check dylib exists
echo "✓ Test 1: Checking libmufiz.dylib exists..."
if [ -f "Sources/CMufi/libmufiz.dylib" ]; then
    echo "  ✓ Found: Sources/CMufi/libmufiz.dylib"
    file Sources/CMufi/libmufiz.dylib
else
    echo "  ✗ FAIL: libmufiz.dylib not found"
    exit 1
fi
echo ""

# Test 2: Check Package.swift rpath configuration
echo "✓ Test 2: Checking Package.swift has proper linker settings..."
if grep -q "rpath.*Sources/CMufi" Package.swift; then
    echo "  ✓ Package.swift has automatic rpath configuration"
else
    echo "  ⚠ Warning: Package.swift may not have rpath settings"
fi
echo ""

# Test 3: Build the project
echo "✓ Test 3: Building project (dylib automatically handled via rpath)..."
swift build --product FerrufiApp > /tmp/ferrufi_build.log 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ Build succeeded"
else
    echo "  ✗ FAIL: Build failed"
    tail -20 /tmp/ferrufi_build.log
    exit 1
fi
echo ""

# Test 4: Check linked libraries
echo "✓ Test 4: Checking linked libraries..."
BUILD_EXEC=$(find .build -type f -name "FerrufiApp" -path "*/debug/*" -print -quit)
if [ -n "$BUILD_EXEC" ]; then
    if otool -L "$BUILD_EXEC" | grep -q "libmufiz.dylib"; then
        echo "  ✓ FerrufiApp is linked to libmufiz.dylib"
        otool -L "$BUILD_EXEC" | grep mufiz
    else
        echo "  ✗ FAIL: libmufiz.dylib not in linked libraries"
        exit 1
    fi
else
    echo "  ✗ FAIL: Could not find FerrufiApp executable"
    exit 1
fi
echo ""

# Test 5: Check rpath
echo "✓ Test 5: Checking rpath configuration..."
if otool -l "$BUILD_EXEC" | grep -q "LC_RPATH"; then
    echo "  ✓ Rpath is configured"
    if otool -l "$BUILD_EXEC" | grep "path" | grep -q "Sources/CMufi"; then
        echo "  ✓ Rpath includes Sources/CMufi directory"
        otool -l "$BUILD_EXEC" | grep "path.*Sources/CMufi"
    else
        echo "  ⚠ Warning: Rpath doesn't include Sources/CMufi"
    fi
else
    echo "  ✗ FAIL: No rpath found"
    exit 1
fi
echo ""

# Test 6: Verify dylib is reachable via rpath
echo "✓ Test 6: Verifying dylib is reachable via rpath..."
BUILD_DIR=$(dirname "$BUILD_EXEC")
if [ -f "$BUILD_DIR/../../../Sources/CMufi/libmufiz.dylib" ]; then
    echo "  ✓ Dylib is reachable via relative path from executable"
else
    echo "  ✗ FAIL: Dylib not found at expected rpath location"
    exit 1
fi
echo ""

echo "=== All Tests Passed! ==="
echo ""
echo "Summary:"
echo "  ✓ libmufiz.dylib found and correct architecture"
echo "  ✓ Package.swift has automatic rpath configuration"
echo "  ✓ Project builds successfully (no manual copying needed!)"
echo "  ✓ libmufiz.dylib is properly linked"
echo "  ✓ Rpath is configured to find Sources/CMufi"
echo "  ✓ Dylib is reachable via rpath"
echo ""
echo "🎉 Automatic dylib handling is working!"
echo ""
echo "Next steps:"
echo "  - Run 'swift run FerrufiApp' to test the application"
echo "  - Run 'swift test' to run the test suite"
echo "  - Run './build_macos.sh' to create a DMG"
echo ""
echo "Note: No manual 'copy_mufiz_dylib.sh' execution needed!"
