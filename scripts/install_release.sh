#!/usr/bin/env sh
# install_release.sh
# Minimal installer: download latest Ferrufi release (Mufi-Lang/Ferrufi),
# install Ferrufi.app into /Applications, and create /usr/local/bin/ferrufi
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install_release.sh | sh
#
# This script is intentionally simple and opinionated:
#  - Always installs the latest GitHub release for Mufi-Lang/Ferrufi
#  - Installs Ferrufi.app to /Applications (overwrites if present)
#  - Creates/overwrites /usr/local/bin/ferrufi -> Ferrufi.app/Contents/MacOS/<executable>
#
set -euo pipefail
IFS='
'

REPO="Mufi-Lang/Ferrufi"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
TMPDIR="$(mktemp -d /tmp/ferrufi.XXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# Ensure required commands are available
for cmd in curl ditto ln chmod; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf "Required command '%s' not found. Please install it and re-run.\n" "$cmd" >&2
    exit 1
  fi
done

echo "Fetching latest release metadata for $REPO..."
# Check the latest release endpoint silently (suppress curl stderr). If it's not available,
# fall back to the 'experimental' prerelease.
HTTP_STATUS="$(curl -sSL -o /dev/null -w "%{http_code}" "$API_URL" 2>/dev/null || true)"

if [ "$HTTP_STATUS" = "200" ]; then
  RELEASE_JSON="$(curl -sSL "$API_URL" 2>/dev/null)" || {
    echo "Failed to fetch release metadata from GitHub (latest)." >&2
    exit 1
  }
else
  echo "Latest release not available (HTTP ${HTTP_STATUS:-unknown}). Trying 'experimental' release tag..."
  TAG_API_URL="https://api.github.com/repos/$REPO/releases/tags/experimental"
  HTTP_STATUS_TAG="$(curl -sSL -o /dev/null -w "%{http_code}" "$TAG_API_URL" 2>/dev/null || true)"

  if [ "$HTTP_STATUS_TAG" = "200" ]; then
    RELEASE_JSON="$(curl -sSL "$TAG_API_URL" 2>/dev/null)" || {
      echo "Failed to fetch 'experimental' release metadata from GitHub." >&2
      exit 1
    }
    echo "Using 'experimental' release"
  else
    echo "Failed to fetch release metadata from GitHub (latest: ${HTTP_STATUS:-unknown}, experimental: ${HTTP_STATUS_TAG:-unknown})." >&2
    exit 1
  fi
fi

# Pick first asset that looks like macOS release: prefer dmg, then zip, then tar.gz
ASSET_URL="$(printf '%s\n' "$RELEASE_JSON" \
  | awk -F\" '/browser_download_url/{print $4}' \
  | grep -E -i '\.(dmg|zip|tar\.gz)$' \
  | head -n1 || true)"

if [ -z "$ASSET_URL" ]; then
  echo "No suitable release asset (.dmg, .zip, .tar.gz) found for $REPO." >&2
  exit 1
fi

ASSET_NAME="$(basename "$ASSET_URL")"
ASSET_PATH="$TMPDIR/$ASSET_NAME"

echo "Downloading asset: $ASSET_NAME ..."
if ! curl -L --fail -o "$ASSET_PATH" "$ASSET_URL" 2>/dev/null; then
  echo "Download failed (HTTP error or asset not accessible): $ASSET_URL" >&2
  exit 1
fi

# Helper: find .app inside path
find_app() {
  find "$1" -maxdepth 4 -type d -name 'Ferrufi.app' -print -quit 2>/dev/null || true
}

APP_SOURCE=""
case "$ASSET_PATH" in
  *.zip)
    mkdir -p "$TMPDIR/extracted"
    unzip -q "$ASSET_PATH" -d "$TMPDIR/extracted" || {
      echo "Failed to unzip archive." >&2
      exit 1
    }
    APP_SOURCE="$(find_app "$TMPDIR/extracted")"
    [ -z "$APP_SOURCE" ] && APP_SOURCE="$(find "$TMPDIR/extracted" -maxdepth 4 -type d -name '*.app' -print -quit || true)"
    ;;
  *.dmg)
    # Mount dmg into a temp mountpoint if possible, fall back to scanning /Volumes
    MOUNT_DIR="$TMPDIR/mnt"
    mkdir -p "$MOUNT_DIR"
    if hdiutil attach "$ASSET_PATH" -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null 2>&1; then
      APP_SOURCE="$(find_app "$MOUNT_DIR")"
    else
      # Fallback: attach without mountpoint and try to find under /Volumes
      hdiutil attach "$ASSET_PATH" -nobrowse >/dev/null 2>&1 || true
      APP_SOURCE="$(find /Volumes -maxdepth 2 -type d -name 'Ferrufi.app' -print -quit 2>/dev/null || true)"
    fi
    ;;
  *.tar.gz|*.tgz)
    mkdir -p "$TMPDIR/extracted"
    tar -xzf "$ASSET_PATH" -C "$TMPDIR/extracted" || {
      echo "Failed to extract tarball." >&2
      exit 1
    }
    APP_SOURCE="$(find_app "$TMPDIR/extracted")"
    [ -z "$APP_SOURCE" ] && APP_SOURCE="$(find "$TMPDIR/extracted" -maxdepth 4 -type d -name '*.app' -print -quit || true)"
    ;;
  *)
    echo "Unsupported asset type: $ASSET_PATH" >&2
    exit 1
    ;;
esac

if [ -z "$APP_SOURCE" ]; then
  echo "Could not locate Ferrufi.app inside the downloaded asset." >&2
  exit 1
fi

DEST_APP="/usr/local/bin/Ferrufi.app"

echo "Installing Ferrufi.app to $DEST_APP ..."
# Ensure /usr/local/bin exists
if [ ! -d "/usr/local/bin" ]; then
  sudo mkdir -p /usr/local/bin
fi
# Remove existing app if present
if [ -d "$DEST_APP" ]; then
  echo "Removing existing app at $DEST_APP ..."
  sudo rm -rf "$DEST_APP"
fi

# Copy the app bundle into /usr/local/bin (use sudo)
sudo ditto -v "$APP_SOURCE" "$DEST_APP"

# Clear Gatekeeper quarantine if possible (non-fatal)
if command -v xattr >/dev/null 2>&1; then
  sudo xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true
fi

# Ensure /Applications contains a symlink pointing to the installed app
if [ -L "/Applications/Ferrufi.app" ] || [ -e "/Applications/Ferrufi.app" ]; then
  sudo rm -rf "/Applications/Ferrufi.app"
fi
sudo ln -sfn "$DEST_APP" "/Applications/Ferrufi.app"

# Find main executable inside the installed app
EXEC_NAME="$(ls "$DEST_APP/Contents/MacOS" 2>/dev/null | head -n1 || true)"
if [ -z "$EXEC_NAME" ]; then
  echo "Failed to find the app executable inside $DEST_APP/Contents/MacOS" >&2
  exit 1
fi
EXEC_PATH="$DEST_APP/Contents/MacOS/$EXEC_NAME"

# Create CLI symlink in /usr/local/bin
SYMLINK="/usr/local/bin/ferrufi"
if [ ! -d "/usr/local/bin" ]; then
  sudo mkdir -p /usr/local/bin
fi
sudo ln -sf "$EXEC_PATH" "$SYMLINK"
sudo chmod +x "$SYMLINK" || true

echo "Installed Ferrufi to $DEST_APP (app symlink at /Applications/Ferrufi.app)"
echo "CLI launcher available at $SYMLINK"
echo "Run 'ferrufi /path/to/folder' to open a folder in Ferrufi."

exit 0
