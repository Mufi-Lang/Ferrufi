#!/bin/zsh
#
# build_app.sh — Build Ferrufi macOS .app bundle (standalone, no DMG)
#
# This script builds a standalone .app bundle that can be distributed directly
# or zipped for easier sharing. No DMG creation - just a ready-to-use app.
#
# Usage:
#   ./scripts/build_app.sh [options]
#
# Options:
#   --version <ver>       Set explicit version (default: auto-detect from git)
#   --debug               Build debug configuration instead of release
#   --output <path>       Output directory for .app (default: current directory)
#   --zip                 Create a .zip archive of the .app bundle
#   -h, --help            Show this help message
#
# Requirements:
#   - macOS 14.0 or later
#   - Swift 6.2 or later
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
VERSION=""
OUTPUT_DIR=""
CREATE_ZIP=0

# Parse arguments
print_usage() {
  cat <<USAGE
Usage: $0 [options]

Build Ferrufi as a standalone macOS .app bundle for distribution.

Options:
  --version <ver>       Set explicit version (default: auto-detect from git)
  --debug               Build debug configuration instead of release
  --output <path>       Output directory for .app (default: current directory)
  --zip                 Create a .zip archive of the .app bundle
  -h, --help            Show this help message

Examples:
  # Basic build (creates Ferrufi.app in current directory)
  $0

  # Build with specific version and create zip
  $0 --version 1.0.0 --zip

  # Build to specific location
  $0 --output ~/Desktop

  # Build debug version
  $0 --debug

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
    --output)
      shift
      OUTPUT_DIR="${1:-}"
      shift
      ;;
    --zip)
      CREATE_ZIP=1
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
║           Ferrufi App Builder (Standalone)           ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
${NC}
BANNER

# Get to repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$REPO_ROOT"

info "Working directory: $REPO_ROOT"

# Set output directory if not specified
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$REPO_ROOT"
else
  # Expand and normalize path
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" 2>/dev/null && pwd -P || echo "$OUTPUT_DIR")"
  if [ ! -d "$OUTPUT_DIR" ]; then
    error "Output directory does not exist: $OUTPUT_DIR"
    exit 1
  fi
fi
info "Output directory: $OUTPUT_DIR"

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
BUNDLE_DIR="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean up any existing bundle in build dir
if [ -d "$BUNDLE_DIR" ]; then
  info "Removing existing app bundle from build directory"
  rm -rf "$BUNDLE_DIR"
fi

# Create bundle structure
info "Creating bundle structure"
mkdir -p "$MACOS_DIR"
mkdir -p "$FRAMEWORKS_DIR"
mkdir -p "$RESOURCES_DIR"

# Add/copy/generate an app icon (AppIcon.icns) if present.
# Priority:
# 1) Resources/AppIcon.icns
# 2) AppIcon.icns at repo root
# 3) Ferrufi.png (generate .icns from the single PNG)
if [ -f "$REPO_ROOT/Resources/AppIcon.icns" ]; then
  info "Copying Resources/AppIcon.icns -> app bundle"
  cp "$REPO_ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "$REPO_ROOT/AppIcon.icns" ]; then
  info "Copying AppIcon.icns -> app bundle"
  cp "$REPO_ROOT/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "$REPO_ROOT/Ferrufi.png" ]; then
  info "Generating AppIcon.icns from Ferrufi.png"
  ICONSET_DIR="$(mktemp -d -t ferrufi-iconset-XXXX)"
  # 16
  sips -z 16 16  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1 || true
  sips -z 32 32  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1 || true
  # 32
  sips -z 32 32  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1 || true
  sips -z 64 64  "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1 || true
  # 128
  sips -z 128 128 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1 || true
  sips -z 256 256 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1 || true
  # 256
  sips -z 256 256 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1 || true
  sips -z 512 512 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1 || true
  # 512
  sips -z 512 512 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1 || true
  sips -z 1024 1024 "$REPO_ROOT/Ferrufi.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1 || true

  if command -v iconutil >/dev/null 2>&1; then
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" >/dev/null 2>&1 || true
    success "Generated AppIcon.icns in resources"
  else
    warn "iconutil not available; skipping AppIcon.icns generation"
  fi
  rm -rf "$ICONSET_DIR"
fi

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
cp "Info.plist" "$CONTENTS_DIR/Info.plist"
# cat > "$CONTENTS_DIR/Info.plist" <<EOF
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
#     <!-- Basic bundle identity -->
#     <key>CFBundleExecutable</key>
#     <string>$APP_NAME</string>
#     <key>CFBundleIdentifier</key>
#     <string>com.ferrufi.$APP_NAME</string>
#     <key>CFBundleName</key>
#     <string>$APP_NAME</string>
#     <key>CFBundleDisplayName</key>
#     <string>Ferrufi</string>
#     <key>CFBundleVersion</key>
#     <string>$VERSION</string>
#     <key>CFBundleShortVersionString</key>
#     <string>$VERSION</string>

#     <!-- Icon -->
#     <key>CFBundleIconFile</key>
#     <string>AppIcon</string>

#     <key>CFBundlePackageType</key>
#     <string>APPL</string>
#     <key>CFBundleSignature</key>
#     <string>????</string>
#     <key>LSMinimumSystemVersion</key>
#     <string>14.0</string>
#     <key>NSHighResolutionCapable</key>
#     <true/>
#     <key>LSApplicationCategoryType</key>
#     <string>public.app-category.productivity</string>

#     <!-- Privacy/help text -->
#     <key>NSAppleEventsUsageDescription</key>
#     <string>Ferrufi needs access to store your notes and scripts in ~/.ferrufi/</string>

#     <!-- Document type associations: folders and markdown/mufi files -->
#     <key>CFBundleDocumentTypes</key>
#     <array>
#       <!-- Folders: allow Finder to offer Ferrufi as an Open With candidate for folders -->
#       <dict>
#         <key>CFBundleTypeName</key>
#         <string>Folders</string>
#         <key>CFBundleTypeRole</key>
#         <string>Editor</string>
#         <key>LSHandlerRank</key>
#         <string>Owner</string>
#         <key>LSItemContentTypes</key>
#         <array>
#           <string>public.directory</string>
#         </array>
#       </dict>

#       <!-- Markdown + Ferrufi workspace files -->
#       <dict>
#         <key>CFBundleTypeName</key>
#         <string>Markdown</string>
#         <key>CFBundleTypeRole</key>
#         <string>Editor</string>
#         <key>CFBundleTypeExtensions</key>
#         <array>
#           <string>md</string>
#           <string>markdown</string>
#           <string>txt</string>
#           <string>mufi</string>
#         </array>
#         <key>CFBundleTypeIconFile</key>
#         <string>AppIcon.icns</string>
#       </dict>
#     </array>

# </dict>
# </plist>
# EOF

success "App bundle created in build directory"

# Ad-hoc sign with entitlements for file access
section "Applying Entitlements"
ENTITLEMENTS_FILE="$REPO_ROOT/Ferrufi.entitlements"

if [ -f "$ENTITLEMENTS_FILE" ]; then
  info "Applying entitlements for file access permissions"

  # Sign dylib first
  if codesign --force --sign "-" "$FRAMEWORKS_DIR/libmufiz.dylib" 2>/dev/null; then
    success "Signed libmufiz.dylib"
  else
    warn "Failed to sign dylib (non-fatal)"
  fi

  # Sign app with entitlements
  if codesign --force --sign "-" --entitlements "$ENTITLEMENTS_FILE" --deep "$BUNDLE_DIR" 2>/dev/null; then
    success "App signed with entitlements (ad-hoc signature)"
    info "This allows the app to access user files and load libmufiz.dylib"
  else
    warn "Failed to apply entitlements (non-fatal)"
    warn "App may have limited file access in Applications folder"
  fi
else
  warn "Entitlements file not found: $ENTITLEMENTS_FILE"
  warn "App may have limited file access in Applications folder"
fi

# Copy to output directory
section "Finalizing"
FINAL_APP_PATH="$OUTPUT_DIR/${APP_NAME}.app"

if [ -d "$FINAL_APP_PATH" ]; then
  info "Removing existing app at output location"
  rm -rf "$FINAL_APP_PATH"
fi

info "Copying app bundle to: $OUTPUT_DIR"
cp -R "$BUNDLE_DIR" "$OUTPUT_DIR/"

if [ -d "$FINAL_APP_PATH" ]; then
  # Remove quarantine attribute so Finder/Gatekeeper does not block launching
  if command -v xattr >/dev/null 2>&1; then
    info "Removing quarantine attribute (if present) from: $FINAL_APP_PATH"
    xattr -dr com.apple.quarantine "$FINAL_APP_PATH" 2>/dev/null || true
  fi
  success "App bundle copied successfully"
else
  error "Failed to copy app bundle to output directory"
  exit 1
fi

# Create zip if requested
ZIP_PATH=""
if [ $CREATE_ZIP -eq 1 ]; then
  section "Creating Zip Archive"
  ZIP_NAME="Ferrufi-${VERSION}-macos.zip"
  ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

  if [ -f "$ZIP_PATH" ]; then
    info "Removing existing zip: $ZIP_NAME"
    rm -f "$ZIP_PATH"
  fi

  info "Creating zip archive"
  cd "$OUTPUT_DIR"
  if zip -r -q "$ZIP_NAME" "${APP_NAME}.app"; then
    ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
    success "Zip created: $ZIP_NAME ($ZIP_SIZE)"
  else
    warn "Failed to create zip archive"
  fi
  cd "$REPO_ROOT"
fi

# Get app size
APP_SIZE=$(du -sh "$FINAL_APP_PATH" | cut -f1)

# Success summary
section "Build Complete"
echo ""
success "✓ Application built successfully!"
echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "${BOLD}App Location:${NC}    $FINAL_APP_PATH"
info "${BOLD}App Size:${NC}        $APP_SIZE"
info "${BOLD}Version:${NC}         $VERSION"
info "${BOLD}Configuration:${NC}   $BUILD_CONFIGURATION"
info "${BOLD}Architecture:${NC}    $DYLIB_ARCH"

if [ -n "$ZIP_PATH" ] && [ -f "$ZIP_PATH" ]; then
  ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
  info "${BOLD}Zip Archive:${NC}     $ZIP_NAME"
  info "${BOLD}Zip Size:${NC}        $ZIP_SIZE"
fi

info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<SUMMARY
${BOLD}Next steps:${NC}
  1. Copy ${APP_NAME}.app to /Applications:
     ${BLUE}cp -R "$FINAL_APP_PATH" /Applications/${NC}

  2. Or double-click to launch directly from:
     ${BLUE}$OUTPUT_DIR${NC}

  3. Share with others:
$(if [ $CREATE_ZIP -eq 1 ]; then
    echo "     ${BLUE}Upload $ZIP_NAME or share $APP_NAME.app${NC}"
  else
    echo "     ${BLUE}Share $APP_NAME.app (or run with --zip to create archive)${NC}"
  fi)

${BOLD}Note:${NC}
  - ${YELLOW}App is ad-hoc signed with entitlements${NC}
  - This allows file access but users still need to:
    • Right-click → Open (first time only)
    • Or allow in System Settings → Privacy & Security
    • Or run: ${BLUE}xattr -cr /Applications/Ferrufi.app${NC}

${GREEN}Happy coding with Ferrufi! 🚀${NC}
SUMMARY

exit 0
