#!/usr/bin/env bash
#
# Ferrufi installer
#
# Fetches the latest "experimental" release zip from GitHub and installs the
# included Ferrufi.app into /Applications (or a custom install directory).
#
# Usage:
#   ./install.sh                # interactive installer (prompts if app exists)
#   ./install.sh --yes          # non-interactive, accept prompts
#   ./install.sh --local file.zip
#   ./install.sh --uninstall
#   ./install.sh --help
#
# Notes:
# - Prefers the 'gh' CLI if available; otherwise falls back to the GitHub API +
#   python3 to find the zip asset.
# - Uses 'ditto' to copy the .app bundle to /Applications preserving metadata.
# - Removes quarantine attribute (xattr -cr) by default after install.
# - You may pass GITHUB_TOKEN env var to increase GitHub API rate limits.
#

set -euo pipefail
IFS=$'\n\t'

REPO="Mufi-Lang/Ferrufi"
TAG="experimental"
APP_NAME="Ferrufi.app"
DEFAULT_INSTALL_DIR="/Applications"

TMPDIR="$(mktemp -d -t ferrufi-install-XXXX)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Helpers
info()  { printf "\033[1;34mℹ\033[0m %s\n" "$*"; }
succ()  { printf "\033[1;32m✔\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m✖\033[0m %s\n" "$*" >&2; }

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --help           Show this help
  --yes, -y        Non-interactive: auto-accept prompts
  --local <file>   Install from a local zip archive instead of fetching release
  --install-dir DIR Install dir (defaults to /Applications)
  --no-quarantine  Skip xattr -cr step
  --uninstall      Remove installed app from the install directory
  --no-sudo        Do not use sudo when copying (useful if you already have permissions)
EOF
}

# Default options
AUTO_YES=0
LOCAL_ZIP=""
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
SKIP_QUARANTINE=0
UNINSTALL=0
USE_SUDO=1

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --yes|-y) AUTO_YES=1; shift ;;
    --local) LOCAL_ZIP="$2"; shift 2 ;;
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --no-quarantine) SKIP_QUARANTINE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --no-sudo) USE_SUDO=0; shift ;;
    *) err "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

confirm() {
  if [[ $AUTO_YES -eq 1 ]]; then
    return 0
  fi
  read -r -p "$1 [y/N] " reply
  case "$reply" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

# Basic environment checks
if [[ "$(uname -s)" != "Darwin" ]]; then
  err "This installer is intended for macOS only."
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  err "Command 'unzip' not found. Please install it (should be available on macOS)."
  exit 1
fi

# Uninstall path
if [[ $UNINSTALL -eq 1 ]]; then
  target="$INSTALL_DIR/$APP_NAME"
  if [[ -d "$target" ]]; then
    if confirm "Remove $target?"; then
      if [[ $USE_SUDO -eq 1 ]]; then
        sudo rm -rf "$target"
      else
        rm -rf "$target"
      fi
      succ "Removed $target"
    else
      info "Uninstall cancelled."
    fi
  else
    warn "No installation found at $target"
  fi
  exit 0
fi

# Determine ZIP file to install
ZIP_PATH=""
if [[ -n "$LOCAL_ZIP" ]]; then
  if [[ ! -f "$LOCAL_ZIP" ]]; then
    err "Local zip not found: $LOCAL_ZIP"
    exit 1
  fi
  ZIP_PATH="$LOCAL_ZIP"
  info "Using local archive: $ZIP_PATH"
else
  # Try gh first (simpler)
  if command -v gh >/dev/null 2>&1; then
    info "Using GitHub CLI to download experimental release for $REPO"
    if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
      err "Release '$TAG' not found for $REPO"
      exit 1
    fi
    if gh release download "$TAG" --repo "$REPO" --pattern '*.zip' --dir "$TMPDIR" >/dev/null 2>&1; then
      ZIP_PATH="$(ls -t "$TMPDIR"/*.zip 2>/dev/null | head -n1 || true)"
      if [[ -z "$ZIP_PATH" ]]; then
        err "No zip asset found in release via gh."
        exit 1
      fi
      succ "Downloaded release archive: $(basename "$ZIP_PATH")"
    else
      warn "gh download failed; falling back to GitHub API via curl"
    fi
  fi

  if [[ -z "$ZIP_PATH" ]]; then
    # Fallback: use GitHub API + python3 to parse assets
    if ! command -v curl >/dev/null 2>&1; then
      err "curl is required to fetch release info."
      exit 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
      err "python3 is required to parse GitHub API responses. Please install it."
      exit 1
    fi

    info "Fetching release info from GitHub API..."
    API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
    # Allow the user to provide GITHUB_TOKEN in env to avoid rate-limiting
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      AUTH_HDR="Authorization: token ${GITHUB_TOKEN}"
      RESPONSE="$(curl -sSL -H "$AUTH_HDR" "$API_URL")"
    else
      RESPONSE="$(curl -sSL "$API_URL")"
    fi

    DOWNLOAD_URL="$(printf '%s' "$RESPONSE" | python3 - <<'PY' 2>/dev/null
import sys, json
try:
    j = json.load(sys.stdin)
    assets = j.get("assets", [])
    for a in assets:
        name = a.get("name", "")
        if name.endswith(".zip"):
            print(a.get("browser_download_url"))
            sys.exit(0)
except Exception:
    pass
sys.exit(1)
PY
)"
    if [[ -z "$DOWNLOAD_URL" ]]; then
      err "Failed to locate zip asset for release '${TAG}'."
      exit 1
    fi
    info "Downloading $DOWNLOAD_URL ..."
    ZIP_PATH="$TMPDIR/release.zip"
    curl -L -o "$ZIP_PATH" "$DOWNLOAD_URL"
    succ "Downloaded release archive"
  fi
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  err "Failed to obtain a zip archive to install."
  exit 1
fi

# Unpack and locate Ferrufi.app
UNPACK_DIR="$TMPDIR/unpack"
mkdir -p "$UNPACK_DIR"
info "Extracting archive..."
unzip -q -o "$ZIP_PATH" -d "$UNPACK_DIR"

APP_BUNDLE="$(find "$UNPACK_DIR" -maxdepth 3 -type d -name "$APP_NAME" -print -quit || true)"
if [[ -z "$APP_BUNDLE" ]]; then
  err "No $APP_NAME found in the archive. Contents:"
  ls -la "$UNPACK_DIR"
  exit 1
fi

info "Found app bundle: $APP_BUNDLE"

# Install location
TARGET="$INSTALL_DIR/$APP_NAME"
if [[ -d "$TARGET" ]]; then
  warn "An existing installation was found at $TARGET"
  if confirm "Overwrite existing installation at $TARGET?"; then
    if [[ $USE_SUDO -eq 1 ]]; then
      sudo rm -rf "$TARGET"
    else
      rm -rf "$TARGET"
    fi
    succ "Removed existing installation"
  else
    info "Aborted by user."
    exit 0
  fi
fi

# Copy using ditto to preserve metadata
info "Installing to $TARGET ..."
if [[ $USE_SUDO -eq 1 ]]; then
  sudo /usr/bin/ditto "$APP_BUNDLE" "$TARGET"
else
  /usr/bin/ditto "$APP_BUNDLE" "$TARGET"
fi

# Optionally remove quarantine
if [[ $SKIP_QUARANTINE -eq 0 ]]; then
  info "Removing quarantine attribute (xattr -cr) …"
  if [[ $USE_SUDO -eq 1 ]]; then
    sudo xattr -cr "$TARGET" || warn "xattr failed"
  else
    xattr -cr "$TARGET" || warn "xattr failed"
  fi
else
  info "Skipping quarantine removal (--no-quarantine)"
fi

# Show entitlements if available
if command -v codesign >/dev/null 2>&1; then
  info "Installed app entitlements (codesign -d --entitlements -):"
  codesign -d --entitlements - "$TARGET" 2>/dev/null || true
fi

succ "Installation complete!"

# Optionally launch
if confirm "Open Ferrufi now?"; then
  open "$TARGET" || warn "Failed to open app"
fi

echo
info "If you prefer manual install, you can run:"
echo "  cp -R \"$APP_BUNDLE\" \"$INSTALL_DIR/\" && xattr -cr \"$INSTALL_DIR/$APP_NAME\""
echo
info "Installer finished."
