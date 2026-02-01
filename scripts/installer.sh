#!/bin/bash
#
# Ferrufi Source-to-App Installer
#
# This script clones the Ferrufi repository, builds the application from source,
# packages it into a .app bundle, installs it to /Applications, and sets up
# a CLI launcher.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/installer.sh | bash
#

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { printf "${BLUE}▶${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
error() { printf "${RED}✗${NC} %s\n" "$*"; exit 1; }

# 1. Environment Check
info "Checking environment..."
if [[ "$(uname -s)" != "Darwin" ]]; then
    error "Ferrufi is only supported on macOS."
fi

if ! command -v swift &> /dev/null; then
    error "Swift is not installed. Please install Xcode Command Line Tools."
fi

if ! command -v git &> /dev/null; then
    error "git is not installed."
fi

# 2. Temporary Directory
TEMP_DIR=$(mktemp -d -t ferrufi-build-XXXX)
REPO_URL="https://github.com/Mufi-Lang/Ferrufi.git"

info "Finding latest version..."
LATEST_TAG=$(git ls-remote --tags --sort="v:refname" "$REPO_URL" | cut -d/ -f3- | tail -n1 | sed 's/\^{}//' || echo "")

if [ -z "$LATEST_TAG" ]; then
    info "No tags found, cloning main branch..."
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR"
else
    info "Cloning latest version ($LATEST_TAG)..."
    git clone --depth 1 --branch "$LATEST_TAG" "$REPO_URL" "$TEMP_DIR"
fi

cd "$TEMP_DIR"

# 3. Build
# We use the existing local build script which handles bundling, dylib linking, and entitlements.
info "Building Ferrufi from source (this may take a minute)..."
if ! ./scripts/build_dmg_local.sh; then
    error "Build failed. Please check the output above for details."
fi

# 4. Install
info "Installing Ferrufi to /Applications (may require sudo)..."
# The build script puts the app in .build/Ferrufi.app
APP_PATH=".build/Ferrufi.app"

if [[ ! -d "$APP_PATH" ]]; then
    # Fallback search if path is different
    APP_PATH=$(find .build -name "Ferrufi.app" -type d | head -n 1)
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    error "Installation failed: Could not locate the built Ferrufi.app bundle."
fi

# Use ditto to preserve metadata and resource forks
sudo ditto "$APP_PATH" "/Applications/Ferrufi.app"

# Remove quarantine attribute so it launches without Gatekeeper warnings
info "Clearing Gatekeeper quarantine..."
sudo xattr -dr com.apple.quarantine "/Applications/Ferrufi.app" 2>/dev/null || true

# 5. CLI Launcher
if [[ ! -d "/usr/local/bin" ]]; then
    info "Creating /usr/local/bin..."
    sudo mkdir -p /usr/local/bin
fi

info "Creating CLI launcher: /usr/local/bin/ferrufi..."
sudo ln -sf "/Applications/Ferrufi.app/Contents/MacOS/Ferrufi" "/usr/local/bin/ferrufi"

# 6. Cleanup
info "Cleaning up temporary build files..."
rm -rf "$TEMP_DIR"

echo ""
success "Ferrufi installed successfully! 🚀"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info " Launch Ferrufi from your Applications folder or via CLI:"
info "   $ ferrufi"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
