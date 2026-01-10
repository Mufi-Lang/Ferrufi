#!/bin/zsh
#
# build_macos.sh — Build Ferrufi macOS .app and package as a DMG.
#
# Improvements:
# - Detects/generates Xcode project, builds Release configuration
# - Bundles `include/libmufiz.dylib` into the App's Frameworks folder and fixes rpath
# - Optionally codesigns the dylib and app if CODESIGN_IDENTITY is set
# - Produces a compressed UDZO DMG named `Ferrufi-<VERSION>-macos.dmg`
# - Optionally uploads the DMG to a GitHub release (defaults to `experimental` tag when run under Actions)
#
# Environment variables:
# - VERSION               Explicit version string (optional). If not provided, derived from the latest git tag or commit SHA.
# - SCHEME                Xcode scheme to build (default: FerrufiApp)
# - DERIVED_DATA_PATH     Where xcodebuild writes build products (default: build/xcode)
# - BUILD_CONFIGURATION   Build configuration (default: Release)
# - CODESIGN_IDENTITY     Optional codesign identity (e.g. "Developer ID Application: Your Name (TEAMID)")
# - RELEASE_TAG           GitHub release tag to use when uploading (default: experimental)
# - UPLOAD_TO_GITHUB      "1" to attempt upload to GitHub release, "0" to skip. Defaults to 1 when running inside GitHub Actions.
# - GITHUB_REPOSITORY     owner/repo for uploading (if not set, script tries to infer from git)
# - GITHUB_TOKEN          token used to authenticate `gh` if needed (in Actions it's provided automatically)
# - KEEP_STAGING          If set to "1", keeps the temporary DMG staging dir for inspection
#
# Notes:
# - This script prefers the `gh` CLI for releasing/uploading artifacts. If `gh` is not available, it will only build the DMG.
# - It's intended to be run on macOS (hdiutil, codesign, install_name_tool, xcodebuild).
#
set -euo pipefail
IFS=$'\n\t'

# Basic logging helpers
info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; }

# Defaults
SCHEME="${SCHEME:-FerrufiApp}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build/xcode}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Release}"
KEEP_STAGING="${KEEP_STAGING:-0}"
RELEASE_TAG="${RELEASE_TAG:-experimental}"

# Convenience: default UPLOAD_TO_GITHUB to 1 when running inside Actions
if [ -z "${UPLOAD_TO_GITHUB+x}" ]; then
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    UPLOAD_TO_GITHUB=1
  else
    UPLOAD_TO_GITHUB=0
  fi
fi

print_usage() {
  cat <<USAGE
Usage: $0 [--keep-staging] [--no-upload] [--version <ver>]

Environment variables:
  VERSION               explicit version string (overrides auto-detection)
  SCHEME                Xcode scheme to build (default: ${SCHEME})
  DERIVED_DATA_PATH     where xcodebuild writes outputs (default: ${DERIVED_DATA_PATH})
  BUILD_CONFIGURATION   build configuration (default: ${BUILD_CONFIGURATION})
  CODESIGN_IDENTITY     codesign identity (optional)
  RELEASE_TAG           GitHub release tag (default: ${RELEASE_TAG})
  UPLOAD_TO_GITHUB      "1" to upload (default: ${UPLOAD_TO_GITHUB})
  KEEP_STAGING          "1" to keep the dmg staging directory for debugging
USAGE
}

# Simple arg parsing
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --keep-staging) KEEP_STAGING=1; shift ;;
    --no-upload) UPLOAD_TO_GITHUB=0; shift ;;
    --version) shift; VERSION="${1:-}"; shift ;;
    *) warn "Ignoring unknown arg: $1"; shift ;;
  esac
done

# Determine VERSION if not provided
if [ -z "${VERSION:-}" ]; then
  VERSION=""
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # try latest tag, else short SHA
    if git describe --tags --abbrev=0 >/dev/null 2>&1; then
      VERSION="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    fi
    if [ -z "$VERSION" ]; then
      VERSION="$(git rev-parse --short HEAD 2>/dev/null || true)"
    fi
  fi
  VERSION="${VERSION:-$(date -u +%Y%m%d%H%M%S)}"
fi
# sanitize (strip leading 'v' if present)
VERSION="${VERSION#v}"

info "Build version: ${VERSION}"
info "Scheme: ${SCHEME}"
info "Derived data path: ${DERIVED_DATA_PATH}"
info "Configuration: ${BUILD_CONFIGURATION}"

# Ensure we run from the repository root (script is intended to be at repo root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$SCRIPT_DIR"

# Generate Xcode project (if needed) and verify Swift toolchain compatibility
REQUIRED_SWIFT_VERSION="$(awk '/^\/\/ swift-tools-version:/ { print $3; exit }' Package.swift 2>/dev/null || true)"
if [ -n "$REQUIRED_SWIFT_VERSION" ]; then
  info "Package requires swift-tools-version: $REQUIRED_SWIFT_VERSION"
  if command -v swift >/dev/null 2>&1; then
    INSTALLED_SWIFT_VERSION="$(swift --version 2>/dev/null | awk '/Swift version/{print $3; exit}' || true)"
    # Extract numeric major/minor for comparison (ignore patch)
    req_major="$(printf '%s' "$REQUIRED_SWIFT_VERSION" | cut -d. -f1)"
    req_minor="$(printf '%s' "$REQUIRED_SWIFT_VERSION" | cut -d. -f2 || echo 0)"
    inst_major="$(printf '%s' "$INSTALLED_SWIFT_VERSION" | cut -d. -f1 || echo 0)"
    inst_minor="$(printf '%s' "$INSTALLED_SWIFT_VERSION" | cut -d. -f2 || echo 0)"
    if [ "$inst_major" -lt "$req_major" ] || { [ "$inst_major" -eq "$req_major" ] && [ "$inst_minor" -lt "$req_minor" ]; }; then
      error "Installed Swift ($INSTALLED_SWIFT_VERSION) is older than the package's required swift-tools-version ($REQUIRED_SWIFT_VERSION)."
      error "Please upgrade your Swift toolchain (install newer Xcode or Swift toolchain) or run on a runner with Swift $REQUIRED_SWIFT_VERSION+."
      error "Example: on GitHub Actions use an Xcode image that includes Swift $REQUIRED_SWIFT_VERSION or add a step to install the matching toolchain."
      exit 1
    fi
  else
    warn "swift not found in PATH; cannot check swift-tools-version. Proceeding hoping an .xcodeproj already exists."
  fi
fi

if command -v swift >/dev/null 2>&1; then
  info "Generating Xcode project from Package.swift (swift package generate-xcodeproj)"
  swift package generate-xcodeproj || info "swift package generate-xcodeproj failed (non-fatal) — if an .xcodeproj already exists this may be fine"
else
  warn "swift not found in PATH; cannot generate Xcode project. Proceeding hoping an .xcodeproj already exists."
fi

# Detect the Xcode project (use first .xcodeproj)
PROJECT_XCODEPROJ="$(ls -1 *.xcodeproj 2>/dev/null | head -n 1 || true)"
if [ -n "$PROJECT_XCODEPROJ" ]; then
  info "Using project: $PROJECT_XCODEPROJ"
  BUILD_METHOD="xcode"
else
  warn "No .xcodeproj found. Falling back to 'swift build' if available and creating a minimal .app bundle for product '$SCHEME'."
  BUILD_METHOD="swift"
fi

# xcodebuild flags: avoid requiring signing when no identity provided
XCODE_FLAGS=()
if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  XCODE_FLAGS+=(CODE_SIGNING_ALLOWED=NO)
fi

# Build (either via xcodebuild or swift build fallback)
if [ "$BUILD_METHOD" = "xcode" ]; then
  info "Building Xcode project..."
  set -o pipefail
  xcodebuild -project "$PROJECT_XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration "$BUILD_CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    clean build "${XCODE_FLAGS[@]}" 2>&1 | sed -u 's/^/[xcodebuild] /' || {
      error "xcodebuild failed; aborting"
      exit 2
    }
else
  if command -v swift >/dev/null 2>&1; then
    # Map the Xcode-style configuration to Swift build config
    if [ "${BUILD_CONFIGURATION}" = "Release" ]; then
      SWIFT_CFG=release
    else
      SWIFT_CFG=debug
    fi

    info "Running 'swift build' for product '$SCHEME' (configuration: $SWIFT_CFG)"
    swift build -c "$SWIFT_CFG" --product "$SCHEME" || {
      error "swift build failed; aborting"
      exit 2
    }

    # Attempt to locate the built executable under .build
    SWIFT_EXECUTABLE="$(find .build -type f -name "$SCHEME" -print -quit 2>/dev/null || true)"
    if [ -z "$SWIFT_EXECUTABLE" ]; then
      SWIFT_EXECUTABLE="$(find .build -type f -name "$SCHEME*" -print -quit 2>/dev/null || true)"
    fi

    if [ -z "$SWIFT_EXECUTABLE" ]; then
      error "Could not find built executable for product '$SCHEME' under .build; aborting"
      exit 2
    fi

    info "Found Swift-built executable: $SWIFT_EXECUTABLE"

    # Prepare a minimal .app bundle so packaging steps can continue the same way as xcodebuild
    # Use the same RELEASE_DIR layout the rest of the script expects
    RELEASE_DIR="${DERIVED_DATA_PATH}/Build/Products/${BUILD_CONFIGURATION}"
    mkdir -p "$RELEASE_DIR"

    APP_NAME="$SCHEME"
    APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"

    info "Creating minimal app bundle at $APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

    cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>org.ferrufi.$APP_NAME</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
</dict>
</plist>
EOF

    cp -f "$SWIFT_EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    info "Minimal app bundle created at $APP_BUNDLE"
  else
    error "swift not available; cannot perform fallback build; aborting"
    exit 2
  fi
fi

# Copy Mufi dynamic library into .build/* so swift-run and run-time testing works
if [ -x "./scripts/copy_mufiz_dylib.sh" ]; then
  info "Copying libmufiz.dylib into swift build outputs (scripts/copy_mufiz_dylib.sh)"
  ./scripts/copy_mufiz_dylib.sh || warn "Failed to copy libmufiz.dylib into build outputs (non-fatal)"
else
  warn "scripts/copy_mufiz_dylib.sh not found or not executable; skipping runtime-copy step"
fi

# Locate the built .app
RELEASE_DIR="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIGURATION"
info "Looking for .app in $RELEASE_DIR ..."
# Avoid non-portable 'find -maxdepth' usage — prefer simple globs and a small depth search.
APP_BUNDLE="$(ls -d "$RELEASE_DIR"/*.app 2>/dev/null | head -n 1 || true)"

if [ -z "$APP_BUNDLE" ]; then
  warn "No .app found under $RELEASE_DIR — build may have failed or scheme name is different"
  # Fallback: scan a few likely depths under the derived data path for .app bundles without relying on GNU-only flags
  APP_BUNDLE=""
  for candidate in "$DERIVED_DATA_PATH"/*.app "$DERIVED_DATA_PATH"/*/*.app "$DERIVED_DATA_PATH"/*/*/*.app; do
    if [ -d "$candidate" ]; then
      APP_BUNDLE="$candidate"
      break
    fi
  done
fi

if [ -z "$APP_BUNDLE" ]; then
  error "No .app bundle found; aborting packaging steps"
  exit 3
fi

info "Found app bundle: $APP_BUNDLE"

# Bundle the dynamic library into the App so the app is self-contained
MUFIZ_DYLIB_SRC="include/libmufiz.dylib"
if [ -f "$MUFIZ_DYLIB_SRC" ]; then
  FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
  info "Bundling $MUFIZ_DYLIB_SRC into $FRAMEWORKS_DIR"
  mkdir -p "$FRAMEWORKS_DIR"
  cp -f "$MUFIZ_DYLIB_SRC" "$FRAMEWORKS_DIR/" || warn "Failed to copy $MUFIZ_DYLIB_SRC into $FRAMEWORKS_DIR (non-fatal)"

  # Set the dylib's install name so the loader finds it via @rpath
  dylib_dest="$FRAMEWORKS_DIR/$(basename "$MUFIZ_DYLIB_SRC")"
  if command -v install_name_tool >/dev/null 2>&1; then
    install_name_tool -id @rpath/"$(basename "$dylib_dest")" "$dylib_dest" || warn "install_name_tool -id failed (non-fatal)"
  fi

  # Ensure the app executable has an rpath pointing to its Frameworks folder
  APP_NAME="$(basename "$APP_BUNDLE" .app)"
  APP_EXECUTABLE="$APP_NAME"
  if [ -f "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE" ]; then
    if command -v install_name_tool >/dev/null 2>&1; then
      install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE" || true
    fi
  else
    warn "Can't find executable $APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE; skipping rpath fix"
  fi
else
  warn "$MUFIZ_DYLIB_SRC not present; ensure the runtime library is available for the app to run at launch time"
fi

# Optionally codesign embedded dylib and app
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
  if command -v codesign >/dev/null 2>&1; then
    info "Codesigning embedded dylib and app with identity: $CODESIGN_IDENTITY (this may be required for distribution)"
    if [ -f "$dylib_dest" ]; then
      codesign --force --sign "$CODESIGN_IDENTITY" --timestamp=none "$dylib_dest" || warn "Signing lib failed (non-fatal)"
    fi
    # Sign the app bundle (use --deep for simplicity here)
    codesign --force --sign "$CODESIGN_IDENTITY" --timestamp=none --deep "$APP_BUNDLE" || warn "Signing app bundle failed (non-fatal)"
    info "Verifying code signature (non-fatal)"
    codesign --verify --deep --strict "$APP_BUNDLE" || warn "codesign verification failed (non-fatal)"
  else
    warn "codesign not found; skipping codesign step"
  fi
else
  info "CODESIGN_IDENTITY not set; skipping codesign step"
fi

# Create a compressed DMG
info "Creating DMG archive..."

# Use a temp staging directory to create a nice layout (App + Applications symlink)
STAGING_DIR="$(mktemp -d "/tmp/ferrufi-dmg.${VERSION}.XXXX")"
trap 'if [ "${KEEP_STAGING}" != "1" ]; then rm -rf -- "$STAGING_DIR"; fi' EXIT INT TERM

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/" || error "Failed copying $APP_BUNDLE to $STAGING_DIR"
ln -s /Applications "$STAGING_DIR/Applications" || true

VOL_NAME="Ferrufi ${VERSION}"
DMG_NAME="Ferrufi-${VERSION}-macos.dmg"
DMG_PATH="${RELEASE_DIR}/${DMG_NAME}"

# Make sure release dir exists
mkdir -p "$(dirname "$DMG_PATH")"

# Create dmg
if command -v hdiutil >/dev/null 2>&1; then
  info "Running hdiutil to create ${DMG_NAME} ..."
  hdiutil create -volname "${VOL_NAME}" -srcfolder "$STAGING_DIR" -ov -format UDZO "${DMG_PATH}" >/dev/null 2>&1 || {
    # Try without suppressing output to show the error
    error "hdiutil failed to create DMG; retrying (output follows)"
    hdiutil create -volname "${VOL_NAME}" -srcfolder "$STAGING_DIR" -ov -format UDZO "${DMG_PATH}"
  }
else
  error "hdiutil not found — cannot create DMG on non-macOS hosts"
  exit 4
fi

# Absolute path for convenience
DMG_ABS="$(cd "$(dirname "$DMG_PATH")" && pwd -P)/$(basename "$DMG_PATH")"

info "Created DMG: ${DMG_ABS}"

# Export DMG path for GitHub Actions if available
if [ "${GITHUB_ACTIONS:-}" = "true" ] && [ -n "${GITHUB_ENV:-}" ]; then
  echo "DMG_PATH=${DMG_ABS}" >> "${GITHUB_ENV}" || warn "Couldn't write DMG_PATH to GITHUB_ENV"
fi

# Optionally upload to GitHub release (uses `gh` CLI)
if [ "${UPLOAD_TO_GITHUB}" = "1" ]; then
  # Determine repository (owner/repo)
  REPO="${GITHUB_REPOSITORY:-${GITHUB_REPO:-}}"
  if [ -z "$REPO" ]; then
    if command -v git >/dev/null 2>&1; then
      ORIGIN_URL="$(git config --get remote.origin.url || true)"
      if [ -n "$ORIGIN_URL" ]; then
        REPO="$(echo "$ORIGIN_URL" | sed -E 's/.*[:\/]([^\/:]+\/[^\/:]+)(\.git)?$/\1/')"
      fi
    fi
  fi

  if [ -z "$REPO" ]; then
    warn "Could not determine repository to upload to; set GITHUB_REPOSITORY or GITHUB_REPO to enable automatic release upload"
  else
    if command -v gh >/dev/null 2>&1; then
      info "Preparing to upload DMG to GitHub release '${RELEASE_TAG}' in ${REPO}"

      # Authenticate if not already authenticated
      if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        if [ -n "${GITHUB_TOKEN:-}" ]; then
          info "Authenticating gh using GITHUB_TOKEN"
          printf '%s' "${GITHUB_TOKEN}" | gh auth login --with-token >/dev/null 2>&1 || warn "gh auth login failed (non-fatal)"
        else
          warn "gh not authenticated and GITHUB_TOKEN is not set; upload may fail"
        fi
      fi

      # Create or upload (with clobber to replace existing asset)
      if gh release view "$RELEASE_TAG" --repo "$REPO" >/dev/null 2>&1; then
        info "Release '$RELEASE_TAG' exists; uploading asset (clobber)"
        gh release upload "$RELEASE_TAG" "$DMG_ABS" --clobber --repo "$REPO" || warn "gh upload failed (non-fatal)"
      else
        info "Creating new pre-release '$RELEASE_TAG' and uploading asset"
        RELEASE_TITLE="Ferrufi ${VERSION} (experimental)"
        RELEASE_NOTES="Automated experimental build: ${VERSION}\n\nCommit: ${GITHUB_SHA:-$(git rev-parse --short HEAD 2>/dev/null || 'unknown')}"
        gh release create "$RELEASE_TAG" "$DMG_ABS" --title "$RELEASE_TITLE" --notes "$RELEASE_NOTES" --prerelease --repo "$REPO" || warn "gh release create failed (non-fatal)"
      fi

      info "GitHub release upload complete (check the release to verify)"
    else
      warn "gh CLI not found; skipping GitHub release upload. Install 'gh' or use a workflow step to upload the artifact."
    fi
  fi
else
  info "UPLOAD_TO_GITHUB is disabled; not uploading DMG to GitHub"
fi

# Successful completion
info "Build + packaging complete. DMG: ${DMG_ABS}"
if [ "${KEEP_STAGING}" = "1" ]; then
  info "Staging directory retained at: ${STAGING_DIR}"
else
  info "Staging directory cleaned up"
fi

exit 0
