#!/usr/bin/env sh
#
# Ferrufi CLI installer (curl-friendly)
#
# Creates a `ferrufi` symlink that points to the Ferrufi app's main executable.
#
# Usage:
#   # Install symlink pointing to /Applications/Ferrufi.app (default location)
#   curl -fsSL https://example.com/path/to/install_cli.sh | sh
#
#   # Install symlink for a specific app bundle path (non-interactive)
#   curl -fsSL https://example.com/path/to/install_cli.sh | sh -s -- /path/to/Ferrufi.app
#
#   # Install into user-local bin dir instead of /usr/local/bin
#   curl -fsSL https://example.com/path/to/install_cli.sh | sh -s -- --user
#
# Options:
#   --help, -h      Show this help
#   --user          Install to a per-user bin directory ($HOME/bin or $HOME/.local/bin)
#   --force, -f     Overwrite any existing installation without prompting
#   --app PATH      Use PATH as the Ferrufi.app bundle instead of searching common locations
#   --dest PATH     Use a custom destination directory for the symlink
#   --dry-run       Show actions but don't modify the system
#
# Notes:
# - The script is safe to run via a curl | sh workflow. It will not attempt to run sudo for you;
#   if /usr/local/bin is not writable, the script will print a suggested sudo command.
# - This script only creates the CLI launcher (symlink) and does not install or copy the .app bundle.
#

set -eu

# Enable 'pipefail' if the shell supports it (POSIX sh compatibility effort)
# shellcheck disable=SC3040
if (set -o pipefail) 2>/dev/null; then
    set -o pipefail
fi

IFS='
'

BIN_NAME="ferrufi"
FORCE=0
USER_INSTALL=0
DRY_RUN=0
QUIET=0
APP_PATH=""
DEST_DIR=""

usage() {
    cat <<USAGE
Usage: $0 [options] [path/to/Ferrufi.app]

Options:
  --help, -h      Show this help
  --user          Install to a per-user bin directory (\$HOME/bin or \$HOME/.local/bin)
  --force, -f     Overwrite any existing installation without prompting
  --app PATH      Use PATH as the Ferrufi.app bundle instead of searching common locations
  --dest PATH     Use a custom destination directory for the symlink
  --dry-run       Show what would be done, but don't modify the system

Examples:
  # Install the CLI pointing to an app in /Applications
  curl -fsSL https://example.com/path/to/install_cli.sh | sh

  # Install into your user bin dir:
  curl -fsSL https://example.com/path/to/install_cli.sh | sh -s -- --user

  # Install a specific app bundle
  curl -fsSL https://example.com/path/to/install_cli.sh | sh -s -- --app /path/to/Ferrufi.app

USAGE
}

err() {
    printf "Error: %s\n" "$*" >&2
}

info() {
    if [ "${QUIET:-0}" -ne 1 ]; then
        printf "› %s\n" "$*"
    fi
}

# Parse args (POSIX / Bourne compatible)
while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --user)
            USER_INSTALL=1
            shift
            ;;
        --force|-f)
            FORCE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --app)
            if [ $# -lt 2 ]; then
                err "--app requires a path argument"
                exit 2
            fi
            APP_PATH="$2"
            shift 2
            ;;
        --dest)
            if [ $# -lt 2 ]; then
                err "--dest requires a path argument"
                exit 2
            fi
            DEST_DIR="$2"
            shift 2
            ;;
        --quiet)
            QUIET=1
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            err "Unknown option: $1"
            usage
            exit 2
            ;;
        *)
            # positional argument: path to Ferrufi.app
            if [ -z "$APP_PATH" ]; then
                APP_PATH="$1"
            else
                err "Unexpected argument: $1"
                usage
                exit 2
            fi
            shift
            ;;
    esac
done

# Locate Ferrufi.app if not provided explicitly
if [ -z "$APP_PATH" ]; then
    CANDIDATES="./Ferrufi.app" "$HOME/Applications/Ferrufi.app" "/Applications/Ferrufi.app"
    for cand in ./Ferrufi.app "$HOME/Applications/Ferrufi.app" /Applications/Ferrufi.app; do
        if [ -d "$cand" ]; then
            APP_PATH="$cand"
            break
        fi
    done

    # If still not found, search /Applications for Ferrufi*.app
    if [ -z "$APP_PATH" ]; then
        for cand in /Applications/Ferrufi*.app; do
            if [ -d "$cand" ]; then
                APP_PATH="$cand"
                break
            fi
        done
    fi
fi

if [ -z "$APP_PATH" ]; then
    err "Could not find Ferrufi.app. Pass an explicit path as the first argument or with --app."
    usage
    exit 2
fi

# Accept tilde in path
APP_PATH="$(cd "$(dirname "$APP_PATH")" 2>/dev/null && pwd -P)/$(basename "$APP_PATH")" || APP_PATH="$APP_PATH"

# Validate app path
case "$APP_PATH" in
    *.app) ;;
    *)
        err "Provided path is not a .app bundle: $APP_PATH"
        exit 2
        ;;
esac

if [ ! -d "$APP_PATH" ]; then
    err "App bundle not found at: $APP_PATH"
    exit 2
fi

# Find the main executable under Contents/MacOS
MACOS_DIR="$APP_PATH/Contents/MacOS"
if [ ! -d "$MACOS_DIR" ]; then
    err "App bundle does not contain Contents/MacOS: $APP_PATH"
    exit 2
fi

BIN_PATH=""
# Find first executable in Contents/MacOS
for f in "$MACOS_DIR"/*; do
    [ -f "$f" ] || continue
    if [ -x "$f" ]; then
        BIN_PATH="$f"
        break
    fi
done

# Fallback: pick the first regular file in that directory
if [ -z "$BIN_PATH" ]; then
    for f in "$MACOS_DIR"/*; do
        [ -f "$f" ] || continue
        BIN_PATH="$f"
        break
    done
fi

if [ -z "$BIN_PATH" ] || [ ! -f "$BIN_PATH" ]; then
    err "Could not find an executable inside $MACOS_DIR"
    exit 1
fi

info "Found Ferrufi executable: $BIN_PATH"

# Determine destination directory
if [ -n "$DEST_DIR" ]; then
    DEST="$DEST_DIR"
elif [ "$USER_INSTALL" -eq 1 ]; then
    if [ -d "$HOME/bin" ]; then
        DEST="$HOME/bin"
    else
        DEST="$HOME/.local/bin"
    fi
else
    DEST="/usr/local/bin"
fi

# Normalize destination path
DEST="$(cd "$(dirname "$DEST")" 2>/dev/null && pwd -P)/$(basename "$DEST")" || DEST="$DEST"

# Create destination directory (only for user install or when run as root)
if [ ! -d "$DEST" ]; then
    if [ "$USER_INSTALL" -eq 1 ] || [ "$(id -u)" -eq 0 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            info "Would create directory: $DEST"
        else
            if mkdir -p "$DEST"; then
                info "Created directory: $DEST"
            else
                err "Failed to create directory: $DEST"
                exit 1
            fi
        fi
    else
        err "$DEST does not exist and cannot be created without privileges."
        err "To install the symlink, run the following command manually (requires sudo):"
        printf "  sudo ln -sf \"%s\" %s/%s\n" "$BIN_PATH" "$DEST" "$BIN_NAME"
        exit 1
    fi
fi

# Ensure destination is writable (or we are root)
if [ ! -w "$DEST" ] && [ "$(id -u)" -ne 0 ]; then
    err "Destination $DEST is not writable by current user."
    err "You can either re-run this script with --user to install into your home directory, or run the following command with sudo:"
    printf "  sudo ln -sf \"%s\" %s/%s\n" "$BIN_PATH" "$DEST" "$BIN_NAME"
    exit 1
fi

SYMLINK="$DEST/$BIN_NAME"

# Handle existing symlink / file
if [ -e "$SYMLINK" ] || [ -L "$SYMLINK" ]; then
    # If it's a symlink pointing to the same target, exit successfully
    if [ -L "$SYMLINK" ] && [ "$(readlink "$SYMLINK")" = "$BIN_PATH" ]; then
        info "CLI launcher already installed: $SYMLINK -> $(readlink "$SYMLINK")"
        exit 0
    fi

    if [ "$FORCE" -eq 1 ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            info "Would remove existing entry at $SYMLINK"
        else
            rm -f "$SYMLINK"
            info "Removed existing entry at $SYMLINK"
        fi
    else
        err "$SYMLINK already exists. Use --force to overwrite or run:"
        printf "  sudo ln -sf \"%s\" %s\n" "$BIN_PATH" "$SYMLINK"
        exit 1
    fi
fi

# Create symlink
if [ "$DRY_RUN" -eq 1 ]; then
    info "Would create symlink: ln -sf \"$BIN_PATH\" \"$SYMLINK\""
    exit 0
fi

if ln -sf "$BIN_PATH" "$SYMLINK"; then
    info "Created CLI launcher: $SYMLINK -> $BIN_PATH"
else
    err "Failed to create symlink at $SYMLINK."
    err "Try running:"
    printf "  sudo ln -sf \"%s\" %s\n" "$BIN_PATH" "$SYMLINK"
    exit 1
fi

# If the installed destination isn't on PATH, print a helpful message
case ":$PATH:" in
    *":$DEST:"*)
        # ok
        ;;
    *)
        info "Note: $DEST is not currently on your PATH."
        info "Add the following to your shell profile (e.g. ~/.bashrc, ~/.zshrc):"
        printf "  export PATH=\"%s:\\$PATH\"\n" "$DEST"
        ;;
esac

info "Done. Test with: $BIN_NAME /path/to/folder (e.g. $BIN_NAME . to open the current directory)"
exit 0
