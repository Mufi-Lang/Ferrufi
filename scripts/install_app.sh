#!/usr/bin/env sh
# Ferrufi - macOS installer helper
#
# Usage:
#   sudo ./scripts/install_app.sh /path/to/Ferrufi.app
#   ./scripts/install_app.sh /path/to/Ferrufi.app --user     # per-user install (no sudo)
#   ./scripts/install_app.sh --user                          # install ./Ferrufi.app into ~/Applications
#   sudo ./scripts/install_app.sh --force /path/to/Ferrufi.app
#
# Behavior:
#  - Copies the .app bundle into /Applications (system) or ~/Applications (user)
#  - Creates a CLI launcher at /usr/local/bin/ferrufi that runs the app's bundled executable
#  - Removes macOS quarantine attribute so Gatekeeper won't block launching from /Applications
#
# Notes:
#  - Prefer installing the .app to /Applications; do NOT put the .app itself in /usr/local/bin.
#  - If /usr/local/bin is not writable, the script will print the exact commands you can run with sudo.
#  - Uses `ditto` to preserve extended attributes and resource forks.

set -euo pipefail
IFS='
'

APP_NAME="Ferrufi.app"
BIN_NAME="ferrufi"
SYMLINK="/usr/local/bin/${BIN_NAME}"

usage() {
  cat <<USAGE
Usage: $0 [options] [path/to/Ferrufi.app]

Options:
  --user        Install into ~/Applications (per-user; no sudo required)
  --force, -f   Overwrite any existing installation without prompting
  --help, -h    Show this help message

Examples:
  # System install (needs sudo)
  sudo $0 /path/to/Ferrufi.app

  # Per-user install (no sudo)
  $0 --user /path/to/Ferrufi.app

  # If you already built the app in the repo root:
  $0 --user ./Ferrufi.app
USAGE
}

err() {
  printf "Error: %s\n" "$*" >&2
}

info() {
  printf "› %s\n" "$*"
}

# Parse args
USER_INSTALL=0
FORCE=0
SRC=""
ALLOW_GATEKEEPER=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      USER_INSTALL=1
      shift
      ;;
    --force|-f)
      FORCE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      --no-sudo) USE_SUDO=0; shift ;;
      --allow-gatekeeper)
        ALLOW_GATEKEEPER=1
        shift
        ;;
      -*) err "Unknown option: $1"
        usage
        exit 2
        ;;
    *)
      if [ -z "$SRC" ]; then
        SRC="$1"
      else
        err "Unexpected argument: $1"
        usage
        exit 2
      fi
      shift
      ;;
  esac
done

# If SRC not provided, try to find a local Ferrufi.app
if [ -z "${SRC:-}" ]; then
  if [ -d "./${APP_NAME}" ]; then
    SRC="./${APP_NAME}"
  else
    err "No app path provided and ${APP_NAME} not found in current directory."
    usage
    exit 2
  fi
fi

# Resolve SRC to absolute path
if [ -d "$SRC" ]; then
  SRC="$(cd "$(dirname "$SRC")" && pwd -P)/$(basename "$SRC")"
else
  err "Specified path is not a directory: $SRC"
  exit 2
fi

# Validate it's an .app bundle
case "$(basename "$SRC")" in
  *.app) ;;
  *)
    err "Source must be an .app bundle: $SRC"
    exit 2
    ;;
esac

# Decide destination
if [ "$USER_INSTALL" -eq 1 ]; then
  DEST_DIR="$HOME/Applications"
  TARGET_PATH="$DEST_DIR/$APP_NAME"
else
  DEST_DIR="/Applications"
  TARGET_PATH="$DEST_DIR/$APP_NAME"
fi

# Perform copy
info "Installing ${APP_NAME} -> ${TARGET_PATH}"
if [ "$USER_INSTALL" -eq 1 ]; then
  mkdir -p "$DEST_DIR"
  if [ -d "$TARGET_PATH" ] && [ "$FORCE" -eq 0 ]; then
    err "${TARGET_PATH} already exists. Use --force to overwrite or remove it manually."
    exit 2
  fi
  rm -rf "$TARGET_PATH"
  ditto -v "$SRC" "$TARGET_PATH"
else
  # System install requires root
  if [ "$(id -u)" -ne 0 ]; then
    err "System install requires sudo. Re-run the script with sudo."
    exit 2
  fi
  if [ -d "$TARGET_PATH" ] && [ "$FORCE" -eq 0 ]; then
    err "${TARGET_PATH} already exists. Use --force to overwrite or remove it manually."
    exit 2
  fi
  rm -rf "$TARGET_PATH"
  ditto -v "$SRC" "$TARGET_PATH"
fi

# Remove quarantine attribute (safe if not present)
info "Clearing Gatekeeper quarantine (if present)"
if command -v xattr >/dev/null 2>&1; then
  if [ "$USER_INSTALL" -eq 1 ]; then
    xattr -dr com.apple.quarantine "$TARGET_PATH" 2>/dev/null || true
  else
    xattr -dr com.apple.quarantine "$TARGET_PATH" 2>/dev/null || true
  fi
fi

# Create a CLI launcher in /usr/local/bin
BIN_PATH="$TARGET_PATH/Contents/MacOS/$BIN_NAME"
if [ ! -x "$BIN_PATH" ]; then
  # If the expected binary name doesn't exist, try to find any executable in MacOS/
  if [ -d "$TARGET_PATH/Contents/MacOS" ]; then
    firstExe=$(find "$TARGET_PATH/Contents/MacOS" -maxdepth 1 -type f -perm +111 -print -quit 2>/dev/null || true)
    if [ -n "$firstExe" ]; then
      BIN_PATH="$firstExe"
      info "Using executable: $BIN_PATH"
    fi
  fi
fi

if [ -x "$BIN_PATH" ]; then
  # Ensure /usr/local/bin exists
  if [ ! -d "/usr/local/bin" ]; then
    if [ "$(id -u)" -ne 0 ]; then
      err "/usr/local/bin does not exist and you are not root. Please create it or run the script as root to create the symlink."
      info "To create the symlink manually, run:"
      printf "  sudo ln -sf \"%s\" %s\n" "$BIN_PATH" "$SYMLINK"
    else
      mkdir -p /usr/local/bin
    fi
  fi

  # Try to create symlink; if we can't write, print instructions for the user
  if ln -sf "$BIN_PATH" "$SYMLINK" 2>/dev/null; then
    chmod +x "$SYMLINK" 2>/dev/null || true
    info "Created CLI launcher: $SYMLINK -> $BIN_PATH"
  else
    err "Failed to create symlink at $SYMLINK (permission issue)."
    info "To create the symlink manually, run:"
    printf "  sudo ln -sf \"%s\" %s\n" "$BIN_PATH" "$SYMLINK"
  fi
else
  err "No executable found inside the app bundle at expected path: $TARGET_PATH/Contents/MacOS/"
  exit 2
fi

info "Installation complete! You can run the app from Finder or via CLI: ${BIN_NAME}"

# Gatekeeper allow-list prompt/auto-add (interactive prompt unless --allow-gatekeeper was passed)
DO_ADD=0
if [ "${ALLOW_GATEKEEPER:-0}" -eq 1 ]; then
  DO_ADD=1
else
  # Ask the user interactively (default No)
  read -r -p "Add Ferrufi to Gatekeeper allowed list (recommended so it opens without extra prompts)? [y/N] " _resp
  case "$_resp" in
    [Yy]* ) DO_ADD=1 ;;
    *) DO_ADD=0 ;;
  esac
fi

if [ "$DO_ADD" -eq 1 ]; then
  if command -v spctl >/dev/null 2>&1; then
    info "Adding Ferrufi to Gatekeeper allowed list (label: Ferrufi)..."
    if [ "$(id -u)" -ne 0 ]; then
      sudo spctl --add --label "Ferrufi" "$TARGET_PATH" 2>/dev/null || warn "spctl --add failed (you may need to run it manually)"
      sudo spctl --enable --label "Ferrufi" 2>/dev/null || true
    else
      spctl --add --label "Ferrufi" "$TARGET_PATH" 2>/dev/null || warn "spctl --add failed"
      spctl --enable --label "Ferrufi" 2>/dev/null || true
    fi
    succ "Added Ferrufi to Gatekeeper allowed list (label: Ferrufi)"
  else
    warn "spctl not available; cannot add to Gatekeeper automatically. You can manually run:\n  sudo spctl --add --label \"Ferrufi\" \"$TARGET_PATH\""
  fi
fi

exit 0
