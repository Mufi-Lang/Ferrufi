#!/usr/bin/env bash
#
# run_app.sh — Build a debug macOS .app and launch it (so the app icon shows in Dock during development)
#
# Usage:
#   ./scripts/run_app.sh        # Build Debug .app and open it
#   ./scripts/run_app.sh --no-open   # Build .app but don't open it
#   ./scripts/run_app.sh --clean     # Remove previous debug .app and rebuild
#   ./scripts/run_app.sh --help      # Show help
#
# Notes:
# - This is intended for development: it produces a debug `.app` in `.build/` and opens it.
# - If an icon file is present at `assets/AppIcon.icns` or a PNG named `Ferrufi.png` exists
#   the script will include an `AppIcon.icns` in the .app so macOS shows your custom app icon.
#
set -euo pipefail
IFS=$'\n\t'

# Helpers
info()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
succ()  { printf "\033[1;32m✔\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m✖\033[0m %s\n" "$*" >&2; }

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  --help         Show this help
  --no-open      Build .app but do not open it
  --clean        Remove existing debug .app before building
  --skip-icon    Don't attempt to include/generate an AppIcon.icns

This script builds the debug product and packages it into a macOS .app located at:
  .build/Ferrufi-debug.app
It will open the app by default so you can see the Dock icon and use the native UI.

EOF
}

# Defaults
OPEN_AFTER_BUILD=true
CLEAN=0
SKIP_ICON=0

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) show_help; exit 0 ;;
    --no-open) OPEN_AFTER_BUILD=false; shift ;;
    --clean) CLEAN=1; shift ;;
    --skip-icon) SKIP_ICON=1; shift ;;
    *) err "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

SCHEME="FerrufiApp"     # Swift product name
APP_NAME="Ferrufi"      # App bundle/display name
BUILD_CONFIG="debug"
BUILD_DIR="$REPO_ROOT/.build"
DEBUG_APP_DIR="$BUILD_DIR/${APP_NAME}-debug.app"
CONTENTS_DIR="$DEBUG_APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Ensure Swift exists
if ! command -v swift >/dev/null 2>&1; then
  err "Swift not found in PATH. Install Xcode command line tools or add Swift to PATH."
  exit 1
fi

# Optionally remove existing debug app
if [[ $CLEAN -eq 1 && -d "$DEBUG_APP_DIR" ]]; then
  info "Removing existing debug app at: $DEBUG_APP_DIR"
  rm -rf "$DEBUG_APP_DIR"
fi

# Build the debug product
info "Building product: $SCHEME (configuration: $BUILD_CONFIG)"
if ! swift build -c "$BUILD_CONFIG" --product "$SCHEME"; then
  err "swift build failed. Fix compilation errors before running this script."
  exit 1
fi
succ "Build succeeded"

# Find the built executable
EXECUTABLE_PATH="$(find "$BUILD_DIR" -type f -name "$SCHEME" -path "*/$BUILD_CONFIG/*" -print -quit || true)"
if [[ -z "$EXECUTABLE_PATH" ]]; then
  err "Could not find built executable for product '$SCHEME' in $BUILD_DIR"
  exit 1
fi
info "Found executable: $EXECUTABLE_PATH"

# Create app bundle structure
info "Creating app bundle at: $DEBUG_APP_DIR"
rm -rf "$DEBUG_APP_DIR"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"

# Copy executable into bundle
info "Copying executable into bundle..."
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Bundle dylib(s) if present (optional)
if [[ -f "Sources/CMufi/libmufiz.dylib" ]]; then
  info "Bundling libmufiz.dylib"
  cp "Sources/CMufi/libmufiz.dylib" "$FRAMEWORKS_DIR/"
  if command -v install_name_tool >/dev/null 2>&1; then
    install_name_tool -id "@rpath/libmufiz.dylib" "$FRAMEWORKS_DIR/libmufiz.dylib" 2>/dev/null || true
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true
  fi
fi

# Info.plist
info "Writing Info.plist"
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple/DTDs/PropertyList-1.0.dtd" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.ferrufi.$APP_NAME.debug</string>
  <key>CFBundleName</key>
  <string>$APP_NAME (Debug)</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleVersion</key>
  <string>debug</string>
  <key>CFBundleShortVersionString</key>
  <string>debug</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>Ferrufi needs access to store your notes and scripts in ~/.ferrufi/</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
</dict>
</plist>
EOF

# Add an icon if available or generate from Ferrufi.png (optional)
if [[ $SKIP_ICON -eq 0 ]]; then
  # Prefer explicit AppIcon.icns in assets, otherwise try Ferrufi.png
  if [[ -f "$REPO_ROOT/assets/AppIcon.icns" ]]; then
    info "Including existing assets/AppIcon.icns"
    cp "$REPO_ROOT/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    succ "App icon included"
  elif [[ -f "$REPO_ROOT/AppIcon.icns" ]]; then
    info "Including AppIcon.icns"
    cp "$REPO_ROOT/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    succ "App icon included"
  elif [[ -f "$REPO_ROOT/Ferrufi.png" ]]; then
    if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
      info "Generating AppIcon.icns from Ferrufi.png (this requires 'sips' and 'iconutil')"
      ICONSET_DIR="$(mktemp -d -t ferrufi-iconset-XXXX)"
      # Create the iconset images at required sizes
      sips -z 16 16  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1 || true
      sips -z 32 32  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1 || true
      sips -z 32 32  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1 || true
      sips -z 64 64  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1 || true
      sips -z 128 128 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1 || true
      sips -z 256 256 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1 || true
      sips -z 256 256 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1 || true
      sips -z 512 512 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1 || true
      sips -z 512 512 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1 || true
      sips -z 1024 1024 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1 || true

      if iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" >/dev/null 2>&1; then
        succ "Generated AppIcon.icns"
      else
        warn "iconutil failed to generate AppIcon.icns"
      fi
      rm -rf "$ICONSET_DIR"
    else
      warn "Cannot generate .icns: 'iconutil' or 'sips' not available. Copy an AppIcon.icns into assets/ or repo root."
    fi
  else
    info "No app icon found (assets/AppIcon.icns or Ferrufi.png). The app will use the default system icon."
  fi
fi

# Remove quarantine (helpful for local dev)
if command -v xattr >/dev/null 2>&1; then
  xattr -dr com.apple.quarantine "$DEBUG_APP_DIR" 2>/dev/null || true
fi

# Open the app (default) so Dock shows the icon and UI is active
if [[ "$OPEN_AFTER_BUILD" == "true" ]]; then
  info "Opening app..."
  if ! open "$DEBUG_APP_DIR"; then
    warn "Failed to open app bundle. You can manually open it at: $DEBUG_APP_DIR"
  else
    succ "App launched"
  fi
else
  info "Build complete. App located at: $DEBUG_APP_DIR"
fi

succ "Run complete"
