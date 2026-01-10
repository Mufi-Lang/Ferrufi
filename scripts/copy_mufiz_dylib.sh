#!/bin/bash
#
# copy_mufiz_dylib.sh — Copy libmufiz.dylib into Swift build outputs
#
# This script ensures that libmufiz.dylib is available in the runtime library search paths
# for both debug and release builds when running via `swift run` or `swift test`.
#
# The dylib is copied to:
# - .build/debug/ (for debug builds)
# - .build/release/ (for release builds)
# - .build/arm64-apple-macosx/debug/ (for architecture-specific debug builds)
# - .build/arm64-apple-macosx/release/ (for architecture-specific release builds)
# - .build/x86_64-apple-macosx/debug/ (for x86_64 debug builds)
# - .build/x86_64-apple-macosx/release/ (for x86_64 release builds)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

DYLIB_SRC="$REPO_ROOT/Sources/CMufi/libmufiz.dylib"

if [ ! -f "$DYLIB_SRC" ]; then
  echo "ERROR: libmufiz.dylib not found at $DYLIB_SRC"
  exit 1
fi

echo "Copying libmufiz.dylib from $DYLIB_SRC to build directories..."

# Copy to common build directories
for build_dir in \
  "$REPO_ROOT/.build/debug" \
  "$REPO_ROOT/.build/release" \
  "$REPO_ROOT/.build/arm64-apple-macosx/debug" \
  "$REPO_ROOT/.build/arm64-apple-macosx/release" \
  "$REPO_ROOT/.build/x86_64-apple-macosx/debug" \
  "$REPO_ROOT/.build/x86_64-apple-macosx/release"
do
  if [ -d "$build_dir" ]; then
    echo "  → $build_dir/"
    cp -f "$DYLIB_SRC" "$build_dir/" || echo "    (failed to copy to $build_dir, continuing...)"
  fi
done

# Also copy to the top-level .build directory if it exists
if [ -d "$REPO_ROOT/.build" ]; then
  echo "  → $REPO_ROOT/.build/"
  cp -f "$DYLIB_SRC" "$REPO_ROOT/.build/" || echo "    (failed to copy to .build root, continuing...)"
fi

echo "Done copying libmufiz.dylib"
exit 0
