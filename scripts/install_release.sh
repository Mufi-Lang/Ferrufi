#!/usr/bin/env sh
#
# install_release.sh
#
# Installs Ferrufi.app into /Applications, clears quarantine, optionally
# adds the app to Gatekeeper's allowed list, creates a CLI launcher in
# /usr/local/bin, and attempts to trigger macOS file/folder permission
# dialogs by launching the app and asking it to open protected folders.
#
# Usage (one-liner):
#   curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install_release.sh | sh
#
# Environment:
#   ALLOW_GATEKEEPER=0     Skip spctl whitelist step (default: 1 / enabled)
#   GITHUB_TOKEN=...       Optional token to increase GitHub API rate limits
#
set -euo pipefail
IFS='
'

REPO="Mufi-Lang/Ferrufi"
FALLBACK_TAG="experimental"
PRIMARY_INSTALL="/Applications/Ferrufi.app"
CLI_SYMLINK="/usr/local/bin/ferrufi"
TMPDIR="$(mktemp -d /tmp/ferrufi.install.XXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

info()  { printf "\033[1;34mℹ\033[0m %s\n" "$*"; }
succ()  { printf "\033[1;32m✔\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m⚠\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m✖\033[0m %s\n" "$*" >&2; }

# Ensure basic tools
for c in curl unzip ditto find ln sudo xattr; do
  if ! command -v "$c" >/dev/null 2>&1; then
    err "Required command '$c' not found. Please install it and re-run."
    exit 1
  fi
done

# Helper: fetch release JSON, preferring latest then fallback tag
fetch_release_json() {
  API_LATEST="https://api.github.com/repos/${REPO}/releases/latest"
  HTTP_STATUS="$(curl -sSL -o /dev/null -w "%{http_code}" "$API_LATEST" 2>/dev/null || true)"
  if [ "$HTTP_STATUS" = "200" ]; then
    curl -sSL "$API_LATEST" 2>/dev/null || return 1
    return 0
  fi

  info "Latest release not available (HTTP ${HTTP_STATUS:-unknown}); trying tag: ${FALLBACK_TAG}"
  API_TAG="https://api.github.com/repos/${REPO}/releases/tags/${FALLBACK_TAG}"
  HTTP_STATUS_TAG="$(curl -sSL -o /dev/null -w "%{http_code}" "$API_TAG" 2>/dev/null || true)"
  if [ "$HTTP_STATUS_TAG" = "200" ]; then
    curl -sSL "$API_TAG" 2>/dev/null || return 1
    return 0
  fi

  return 1
}

# Prefer deterministic experimental asset name when present
choose_asset_url() {
  RELEASE_JSON="$1"
  TARGET_NAME="Ferrufi-experimental.zip"

  # look for exact match first
  echo "$RELEASE_JSON" \
    | awk -F\" -v target="$TARGET_NAME" '/"name"/ { name=$4 } /browser_download_url/ { if (name == target) { print $4; exit } }' \
    | grep -E -i '\.(zip|dmg|tar\.gz)$' || true

  if [ -n "$RETVAL" ]; then
    return 0
  fi

  # fallback: first downloadable macOS-like asset
  echo "$RELEASE_JSON" \
    | awk -F\" '/browser_download_url/{print $4}' \
    | grep -E -i '\.(dmg|zip|tar\.gz)$' \
    | head -n1 || true
}

info "Fetching release metadata for ${REPO}..."
if ! RELEASE_JSON="$(fetch_release_json)"; then
  err "Failed to fetch release metadata for ${REPO} (tried latest and ${FALLBACK_TAG})."
  exit 1
fi

# Determine asset URL
ASSET_URL="$(printf '%s\n' "$RELEASE_JSON" \
  | awk -F\" -v target=\"Ferrufi-experimental.zip\" '/"name"/ { name=$4 } /browser_download_url/ { if (name == target) { print $4; exit } }' || true)"

if [ -z "$ASSET_URL" ]; then
  ASSET_URL="$(printf '%s\n' "$RELEASE_JSON" \
    | awk -F\" '/browser_download_url/{print $4}' \
    | grep -E -i '\.(dmg|zip|tar\.gz)$' \
    | head -n1 || true)"
fi

if [ -z "$ASSET_URL" ]; then
  err "No suitable release asset (.dmg, .zip, .tar.gz) found in the release."
  exit 1
fi

ASSET_NAME="$(basename "$ASSET_URL")"
ASSET_PATH="$TMPDIR/$ASSET_NAME"

info "Downloading asset: $ASSET_NAME ..."
if ! curl -L --fail -o "$ASSET_PATH" "$ASSET_URL"; then
  err "Failed to download asset: $ASSET_URL"
  exit 1
fi
succ "Downloaded $ASSET_NAME"

# Extract and find the .app bundle
find_app_in_dir() {
  find "$1" -maxdepth 6 -type d -name 'Ferrufi.app' -print -quit 2>/dev/null || true
}

APP_SOURCE=""
case "$ASSET_PATH" in
  *.zip)
    unzip -q -o "$ASSET_PATH" -d "$TMPDIR/extracted" || { err "Unzip failed"; exit 1; }
    APP_SOURCE="$(find_app_in_dir "$TMPDIR/extracted")"
    ;;
  *.dmg)
    MOUNT="$TMPDIR/mnt"
    mkdir -p "$MOUNT"
    if hdiutil attach "$ASSET_PATH" -nobrowse -mountpoint "$MOUNT" >/dev/null 2>&1; then
      APP_SOURCE="$(find_app_in_dir "$MOUNT")"
      hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    else
      # fallback: attach and search /Volumes
      hdiutil attach "$ASSET_PATH" -nobrowse >/dev/null 2>&1 || true
      APP_SOURCE="$(find /Volumes -maxdepth 2 -type d -name 'Ferrufi.app' -print -quit 2>/dev/null || true)"
    fi
    ;;
  *.tar.gz|*.tgz)
    mkdir -p "$TMPDIR/extracted"
    tar -xzf "$ASSET_PATH" -C "$TMPDIR/extracted" || { err "Failed to extract tarball"; exit 1; }
    APP_SOURCE="$(find_app_in_dir "$TMPDIR/extracted")"
    ;;
  *)
    err "Unsupported asset type: $ASSET_PATH"
    exit 1
    ;;
esac

if [ -z "$APP_SOURCE" ]; then
  err "Could not locate Ferrufi.app inside the downloaded asset."
  exit 1
fi

info "Found app bundle at: $APP_SOURCE"

# Install to /Applications (required for consistent macOS TCC behavior)
info "Installing Ferrufi to ${PRIMARY_INSTALL} ..."
if [ ! -d "/Applications" ]; then
  sudo mkdir -p /Applications
fi

if [ -d "$PRIMARY_INSTALL" ]; then
  info "Removing existing installation at ${PRIMARY_INSTALL} ..."
  sudo rm -rf "$PRIMARY_INSTALL"
fi

sudo ditto -v "$APP_SOURCE" "$PRIMARY_INSTALL"
succ "Copied app to ${PRIMARY_INSTALL}"

# Remove quarantine attribute so Gatekeeper dialogs are reduced
if command -v xattr >/dev/null 2>&1; then
  info "Removing com.apple.quarantine attribute..."
  sudo xattr -dr com.apple.quarantine "$PRIMARY_INSTALL" 2>/dev/null || warn "xattr removal failed (non-fatal)"
fi

# Optionally add to Gatekeeper's allowed list (spctl); opt-out via ALLOW_GATEKEEPER=0
if [ "${ALLOW_GATEKEEPER:-1}" != "0" ]; then
  if command -v spctl >/dev/null 2>&1; then
    info "Adding Ferrufi to Gatekeeper allowed list (label: Ferrufi). Sudo may be required."
    if sudo spctl --add --label "Ferrufi" "$PRIMARY_INSTALL" 2>/dev/null; then
      sudo spctl --enable --label "Ferrufi" 2>/dev/null || true
      succ "Ferrufi added to Gatekeeper allowed list (label: Ferrufi)."
    else
      warn "spctl --add failed. You can add manually: sudo spctl --add --label \"Ferrufi\" \"$PRIMARY_INSTALL\""
    fi
  else
    warn "spctl not available on this system."
  fi
else
  info "Skipping Gatekeeper whitelist step (ALLOW_GATEKEEPER=0)."
fi

# Create CLI symlink
info "Creating CLI launcher at ${CLI_SYMLINK} ..."
EXEC_NAME="$(ls "$PRIMARY_INSTALL/Contents/MacOS" 2>/dev/null | head -n1 || true)"
if [ -z "$EXEC_NAME" ]; then
  err "Cannot find app executable inside ${PRIMARY_INSTALL}/Contents/MacOS"
  exit 1
fi
EXEC_PATH="$PRIMARY_INSTALL/Contents/MacOS/$EXEC_NAME"

if [ ! -d "/usr/local/bin" ]; then
  sudo mkdir -p /usr/local/bin
fi
sudo ln -sf "$EXEC_PATH" "$CLI_SYMLINK"
sudo chmod +x "$CLI_SYMLINK" || true
succ "CLI launcher created: $CLI_SYMLINK"

succ "Installation finished."

#
# Trigger permission dialogs:
# An installer cannot grant TCC (Privacy) permissions. The app must request them,
# or the user must add the app manually in System Settings -> Privacy & Security.
#
# To make it easy for users, we:
#  - Launch the app so it can present standard NSOpenPanel dialogs when needed
#  - Ask the app to open common protected folders (Documents/Downloads/Desktop)
#    which should cause macOS to show permission dialogs for that app when it
#    attempts to access those locations.
#  - Open the Security & Privacy preference pane so the user can manually allow access.
#
if command -v open >/dev/null 2>&1; then
  info "Launching Ferrufi to allow it to request file/folder access..."
  open "$PRIMARY_INSTALL" >/dev/null 2>&1 || warn "Failed to launch Ferrufi automatically; please open /Applications/Ferrufi.app"

  info "Requesting access to common protected folders (approve any prompts that appear)..."
  # 'open -a <app> <path>' asks the app to open the path which should trigger
  # the app's open-file handling (and any permission dialogs it presents).
  open -a "$PRIMARY_INSTALL" "$HOME/Documents" >/dev/null 2>&1 || true
  open -a "$PRIMARY_INSTALL" "$HOME/Downloads" >/dev/null 2>&1 || true
  open -a "$PRIMARY_INSTALL" "$HOME/Desktop" >/dev/null 2>&1 || true

  # Also try calling the CLI helper to open Documents (if the app supports CLI open)
  if [ -x "$CLI_SYMLINK" ]; then
    "$CLI_SYMLINK" "$HOME/Documents" >/dev/null 2>&1 || true
  fi

  # Open the Security & Privacy preference pane (Privacy tab) to help the user
  if [ -e "/System/Library/PreferencePanes/Security.prefPane" ]; then
    info "Opening System Preferences -> Security & Privacy (Privacy tab). Add Ferrufi to Full Disk Access / Files and Folders if required."
    open "/System/Library/PreferencePanes/Security.prefPane" >/dev/null 2>&1 || true
  else
    info "Please open System Settings -> Privacy & Security to grant Ferrufi access if needed."
  fi

  info "If you don't see permission dialogs, open Ferrufi and use File > Open... to select the folders you want it to access. Approve the macOS dialogs to grant access."
else
  warn "Cannot open GUI applications from this environment. Please open /Applications/Ferrufi.app manually and grant file/folder access via the dialogs or System Settings -> Privacy & Security."
fi

exit 0
