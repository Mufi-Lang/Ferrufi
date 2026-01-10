#!/bin/zsh
#
# build_dmg_local.sh — Build Ferrufi macOS .app and package as a DMG (local builds only)
#
# This is a simplified version of the build script specifically for local development.
# No GitHub upload, no CI/CD complexity - just builds a DMG for local distribution.
#
# Usage:
#   ./scripts/build_dmg_local.sh [options]
#
# Options:
#   --version <ver>       Set explicit version (default: auto-detect from git)
#   --debug               Build debug configuration instead of release
#   --no-codesign         Skip code signing even if identity is available
#   --keep-staging        Keep temporary DMG staging directory after build
#   -h, --help            Show this help message
#
# Environment variables:
#   CODESIGN_IDENTITY     Code signing identity (e.g. "Developer ID Application: Your Name")
#                         If not set, app will be built without signing
#
# Requirements:
#   - macOS 14.0 or later
#   - Swift 6.2 or later
#   - Xcode command line tools (for codesign, hdiutil)
#
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging helpers
info()  { printf "${BLUE}▶${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
error() { printf "${RED}✗${NC} %s\n" "$*"; >&2 }
section() { printf "\n${BOLD}━━━ %s ━━━${NC}\n" "$*"; }

# Defaults
SCHEME="FerrufiApp"
BUILD_CONFIGURATION="Release"
KEEP_STAGING=0
SKIP_CODESIGN=0
VERSION=""

# Parse arguments
print_usage() {
  cat <<USAGE
Usage: $0 [options]

Build Ferrufi as a macOS .app and package it in a DMG for distribution.

Options:
  --version <ver>       Set explicit version (default: auto-detect from git)
  --debug               Build debug configuration instead of release
  --no-codesign         Skip code signing
  --keep-staging        Keep temporary DMG staging directory
  -h, --help            Show this help message

Environment:
  CODESIGN_IDENTITY     Code signing identity (optional)

Examples:
  # Basic build
  $0

  # Build with specific version
  $0 --version 1.0.0

  # Build debug version
  $0 --debug

  # Build without code signing
  $0 --no-codesign

USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
    --version)
      shift
      VERSION="${1:-}"
      shift
      ;;
    --debug)
      BUILD_CONFIGURATION="Debug"
      shift
      ;;
    --no-codesign)
      SKIP_CODESIGN=1
      shift
      ;;
    --keep-staging)
      KEEP_STAGING=1
      shift
      ;;
    *)
      error "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Banner
cat <<BANNER
${BOLD}
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║           Ferrufi DMG Builder (Local)                ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
${NC}
BANNER

# Get to repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

info "Working directory: $REPO_ROOT"

# Determine version if not provided
section "Version Detection"
if [ -z "$VERSION" ]; then
  # Try to read from Version.swift first
  VERSION_FILE="$REPO_ROOT/Sources/Ferrufi/Version.swift"
  if [ -f "$VERSION_FILE" ]; then
    MAJOR=$(grep -E '^\s*public static let major = ' "$VERSION_FILE" | sed 's/.*= //' | tr -d ' ')
    MINOR=$(grep -E '^\s*public static let minor = ' "$VERSION_FILE" | sed 's/.*= //' | tr -d ' ')
    PATCH=$(grep -E '^\s*public static let patch = ' "$VERSION_FILE" | sed 's/.*= //' | tr -d ' ')
    if [ -n "$MAJOR" ] && [ -n "$MINOR" ] && [ -n "$PATCH" ]; then
      VERSION="${MAJOR}.${MINOR}.${PATCH}"
      info "Version from Version.swift: $VERSION"
    fi
  fi

  # Fallback to git if Version.swift didn't work
  if [ -z "$VERSION" ]; then
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      # Try latest tag
      if git describe --tags --abbrev=0 >/dev/null 2>&1; then
        VERSION="$(git describe --tags --abbrev=0 2>/dev/null)"
        info "Version from git tag: $VERSION"
      else
        # Use short commit SHA
        VERSION="$(git rev-parse --short HEAD 2>/dev/null)"
        info "Version from git commit: $VERSION"
      fi
    else
      # Fallback to timestamp
      VERSION="$(date -u +%Y%m%d%H%M%S)"
      warn "Git not available, using timestamp: $VERSION"
    fi
  fi
else
  info "Using provided version: $VERSION"
fi

# Strip leading 'v' if present
VERSION="${VERSION#v}"
success "Build version: $VERSION"

# Check for libmufiz.dylib
section "Dependencies Check"
DYLIB_PATH="$REPO_ROOT/Sources/CMufi/libmufiz.dylib"
if [ ! -f "$DYLIB_PATH" ]; then
  error "libmufiz.dylib not found at: $DYLIB_PATH"
  error "Please ensure the Mufi runtime library is present"
  exit 1
fi
success "Found libmufiz.dylib"

# Check architecture
DYLIB_ARCH=$(lipo -info "$DYLIB_PATH" 2>/dev/null | awk '{print $NF}' || echo "unknown")
info "Dylib architecture: $DYLIB_ARCH"

# Check Swift version
section "Build Environment"
if command -v swift >/dev/null 2>&1; then
  SWIFT_VERSION=$(swift --version | head -1)
  info "Swift: $SWIFT_VERSION"
else
  error "Swift not found in PATH"
  exit 1
fi

# Check required tools
REQUIRED_TOOLS=("hdiutil")
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    error "Required tool not found: $tool"
    exit 1
  fi
done
success "Build environment ready"

# Build the app
section "Building Application"
info "Scheme: $SCHEME"
info "Configuration: $BUILD_CONFIGURATION"

BUILD_DIR="$REPO_ROOT/.build"

if [ "$BUILD_CONFIGURATION" = "Release" ]; then
  SWIFT_CONFIG="release"
else
  SWIFT_CONFIG="debug"
fi

info "Running: swift build -c $SWIFT_CONFIG --product $SCHEME"
if swift build -c "$SWIFT_CONFIG" --product "$SCHEME"; then
  success "Build completed successfully"
else
  error "Build failed"
  exit 1
fi

# Find the built executable
EXECUTABLE=$(find "$BUILD_DIR" -type f -name "$SCHEME" -path "*/$SWIFT_CONFIG/*" -print -quit 2>/dev/null || true)
if [ -z "$EXECUTABLE" ]; then
  error "Could not find built executable for $SCHEME"
  exit 1
fi
info "Built executable: $EXECUTABLE"

# Create .app bundle
section "Creating App Bundle"
APP_NAME="Ferrufi"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean up any existing bundle
if [ -d "$BUNDLE_DIR" ]; then
  info "Removing existing app bundle"
  rm -rf "$BUNDLE_DIR"
fi

# Create bundle structure
info "Creating bundle structure"
mkdir -p "$MACOS_DIR"
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
info "Copying executable"
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy libmufiz.dylib to Frameworks
info "Bundling libmufiz.dylib"
cp "$DYLIB_PATH" "$FRAMEWORKS_DIR/"

# Fix dylib install name
if command -v install_name_tool >/dev/null 2>&1; then
  info "Fixing dylib install name"
  install_name_tool -id "@rpath/libmufiz.dylib" "$FRAMEWORKS_DIR/libmufiz.dylib" 2>/dev/null || true

  # Add rpath to executable
  info "Adding rpath to executable"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/$APP_NAME" 2>/dev/null || true
fi

# Create Info.plist
info "Creating Info.plist"
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.ferrufi.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Ferrufi</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
</dict>
</plist>
EOF

success "App bundle created: $BUNDLE_DIR"

# Code signing
section "Code Signing"
if [ $SKIP_CODESIGN -eq 1 ]; then
  warn "Code signing skipped (--no-codesign)"
elif [ -n "${CODESIGN_IDENTITY:-}" ]; then
  info "Code signing identity: $CODESIGN_IDENTITY"

  # Sign dylib
  if codesign --force --sign "$CODESIGN_IDENTITY" "$FRAMEWORKS_DIR/libmufiz.dylib" 2>/dev/null; then
    success "Signed libmufiz.dylib"
  else
    warn "Failed to sign libmufiz.dylib (non-fatal)"
  fi

  # Sign app bundle
  if codesign --force --sign "$CODESIGN_IDENTITY" --deep "$BUNDLE_DIR" 2>/dev/null; then
    success "Signed app bundle"
  else
    warn "Failed to sign app bundle (non-fatal)"
  fi
else
  warn "No code signing identity provided"
  warn "Set CODESIGN_IDENTITY environment variable to sign the app"
  info "App will run on your Mac but may not be distributable"
fi

# Create DMG
section "Creating DMG"
DMG_NAME="Ferrufi-${VERSION}-macos.dmg"
DMG_PATH="$REPO_ROOT/$DMG_NAME"
DMG_STAGING="$BUILD_DIR/dmg_staging"
DMG_VOLUME_NAME="Ferrufi $VERSION"

# Clean up staging and old DMG
if [ -d "$DMG_STAGING" ]; then
  rm -rf "$DMG_STAGING"
fi
if [ -f "$DMG_PATH" ]; then
  info "Removing existing DMG: $DMG_NAME"
  rm -f "$DMG_PATH"
fi

# Create staging directory
info "Creating DMG staging directory"
mkdir -p "$DMG_STAGING"

# Copy app bundle to staging
info "Copying app bundle to staging"
cp -R "$BUNDLE_DIR" "$DMG_STAGING/"

# Create Applications symlink
info "Creating Applications symlink"
ln -s /Applications "$DMG_STAGING/Applications"

# Create temporary DMG
info "Creating temporary DMG"
TEMP_DMG="$BUILD_DIR/temp.dmg"
if [ -f "$TEMP_DMG" ]; then
  rm -f "$TEMP_DMG"
fi

hdiutil create -volname "$DMG_VOLUME_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov -format UDRW \
  "$TEMP_DMG"

# Mount temporary DMG (optional customization step - skip for now to avoid hanging)
# If you want to customize icon positions, uncomment this section
# info "Mounting DMG for customization"
# MOUNT_DIR="/Volumes/$DMG_VOLUME_NAME"
# hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" >/dev/null 2>&1
# sleep 2
# # Set custom icon positions with osascript here
# hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true

info "Skipping DMG customization (use default layout)"

# Convert to compressed DMG
info "Compressing DMG (UDZO format)"
hdiutil convert "$TEMP_DMG" \
  -format UDZO \
  -o "$DMG_PATH" \
  -ov

# Clean up
info "Cleaning up temporary files"
rm -f "$TEMP_DMG"

if [ $KEEP_STAGING -eq 0 ]; then
  rm -rf "$DMG_STAGING"
else
  info "Keeping staging directory: $DMG_STAGING"
fi

# Verify DMG
if [ -f "$DMG_PATH" ]; then
  DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
  success "DMG created successfully!"
  echo ""
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "${BOLD}DMG Location:${NC} $DMG_PATH"
  info "${BOLD}DMG Size:${NC}     $DMG_SIZE"
  info "${BOLD}Version:${NC}      $VERSION"
  info "${BOLD}Config:${NC}       $BUILD_CONFIGURATION"
  info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  success "You can now distribute this DMG!"
  info "To test: open $DMG_NAME"
else
  error "DMG creation failed"
  exit 1
fi

# Final summary
section "Build Complete"
cat <<SUMMARY
${GREEN}✓${NC} Application built successfully
${GREEN}✓${NC} libmufiz.dylib bundled
${GREEN}✓${NC} DMG packaged and ready

${BOLD}Next steps:${NC}
  1. Test the DMG: ${BLUE}open $DMG_NAME${NC}
  2. Drag Ferrufi.app to Applications
  3. Launch Ferrufi from Applications

${BOLD}Note:${NC}
  - If unsigned, you may need to allow the app in:
    System Settings → Privacy & Security
  - Or right-click the app and select "Open"

${BOLD}Build info:${NC}
  - Version:        $VERSION
  - Configuration:  $BUILD_CONFIGURATION
  - Architecture:   $DYLIB_ARCH
  - DMG:            $DMG_NAME

${GREEN}Happy coding with Ferrufi! 🚀${NC}
SUMMARY

exit 0
