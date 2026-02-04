#!/usr/bin/env bash
#
# build_mufiz.sh
#
# Build or download a libmufiz shared library for use with Ferrufi on Linux.
#
# Usage:
#   MUFIZ_PREBUILT_URL="https://example.com/libmufiz.so" ./scripts/build_mufiz.sh
#   MUFIZ_GIT_URL="https://github.com/example/mufiz.git" MUFIZ_TAG="v1.2.3" ./scripts/build_mufiz.sh
#   MUFIZ_GIT_URL="..." MUFIZ_BUILD_CMD="zig build -Drelease-fast" ./scripts/build_mufiz.sh
#
# Environment variables:
#   MUFIZ_PREBUILT_URL  - URL to download a prebuilt artifact (raw .so or archive)
#   MUFIZ_GIT_URL       - Git repo to clone (if building from source)
#   MUFIZ_TAG           - Branch or tag to checkout (defaults to 'main' if not set)
#   MUFIZ_BUILD_CMD     - Explicit build command to run in the source directory
#   MUFIZ_TARGET        - Optional target triple for zig (e.g. x86_64-linux-gnu)
#   MUFIZ_OUT_DIR       - Destination directory (default: Sources/CMufi)
#   MUFIZ_LIB_NAME      - Output library filename (default: libmufiz.so on Linux)
#
# Notes:
# - The script attempts to download a prebuilt artifact (if provided), otherwise it
#   tries to clone the repository and build using sensible defaults (Zig preferred).
# - The final library is copied into MUFIZ_OUT_DIR with the chosen MUFIZ_LIB_NAME so
#   the Swift package can link against it (Package.swift already links with -L Sources/CMufi).
# - This script is intentionally conservative and prints helpful diagnostics for CI.
#

set -euo pipefail

# ---------- helpers ----------
err() { printf "ERROR: %s\n" "$*" >&2; }
info() { printf "INFO: %s\n" "$*"; }
die() { err "$*"; exit 1; }

require() {
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            die "required command not found: $cmd"
        fi
    done
}

# ---------- configuration ----------
OS="$(uname -s)"
ARCH="$(uname -m)"
WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${MUFIZ_OUT_DIR:-$WORKDIR/Sources/CMufi}"
if [[ "$OS" == "Darwin" ]]; then
    OUT_NAME="${MUFIZ_LIB_NAME:-libmufiz.dylib}"
else
    OUT_NAME="${MUFIZ_LIB_NAME:-libmufiz.so}"
fi

PREBUILT_URL="${MUFIZ_PREBUILT_URL:-}"
GIT_URL="${MUFIZ_GIT_URL:-}"
TAG="${MUFIZ_TAG:-main}"
BUILD_CMD="${MUFIZ_BUILD_CMD:-}"
TARGET="${MUFIZ_TARGET:-}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Ensure target directory exists
mkdir -p "$OUT_DIR"

# ---------- utilities ----------
download() {
    local url="$1"
    local out="$2"

    info "Downloading $url ..."
    if command -v curl >/dev/null 2>&1; then
        curl -fSL "$url" -o "$out" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$out" "$url" || return 1
    else
        die "Neither curl nor wget is available to download artifacts."
    fi
    return 0
}

extract_and_find_lib() {
    local artifact="$1"
    local dest="$2"
    local tmp="$TMPDIR/extract"
    mkdir -p "$tmp"

    case "$artifact" in
        *.so|*.dylib|*.dll)
            info "Artifact appears to be a shared library. Copying to destination."
            cp "$artifact" "$dest"
            return 0
            ;;
        *.tar.gz|*.tgz)
            info "Extracting tar.gz archive..."
            tar -xzf "$artifact" -C "$tmp" || return 1
            ;;
        *.tar|*.tbz2|*.tar.bz2)
            info "Extracting tar archive..."
            tar -xf "$artifact" -C "$tmp" || return 1
            ;;
        *.zip)
            if ! command -v unzip >/dev/null 2>&1; then
                die "unzip not present; cannot extract zip artifact"
            fi
            info "Unzipping archive..."
            unzip -q "$artifact" -d "$tmp" || return 1
            ;;
        *)
            # Unknown extension. Try extracting as a tar.gz first, then zip.
            info "Unknown artifact type; attempting tar extraction..."
            if tar -xzf "$artifact" -C "$tmp" 2>/dev/null; then
                :
            elif command -v unzip >/dev/null 2>&1 && unzip -q "$artifact" -d "$tmp" 2>/dev/null; then
                :
            else
                err "Could not extract artifact. Move it to $dest manually if it contains the library."
                return 2
            fi
            ;;
    esac

    # Find a candidate library inside the extracted tree.
    local found
    found="$(find "$tmp" -type f -name 'libmufiz.*' -print -quit || true)"
    if [[ -z "$found" ]]; then
        err "No libmufiz.* found inside archive."
        return 3
    fi
    info "Found built library: $found"
    cp "$found" "$dest"
    return 0
}

find_built_lib() {
    local search_dir="$1"
    # prefer exact .so name and fallback to any libmufiz.*
    local exact="$search_dir/$OUT_NAME"
    if [[ -f "$exact" ]]; then
        echo "$exact"
        return 0
    fi
    # Find any libmufiz.*
    find "$search_dir" -type f -name 'libmufiz.*' -print -quit || true
}

# ---------- download prebuilt artifact ----------
if [[ -n "$PREBUILT_URL" ]]; then
    info "Prebuilt URL provided; attempting download."
    ARTIFACT="$TMPDIR/artifact"
    download "$PREBUILT_URL" "$ARTIFACT" || die "Failed to download artifact."

    # If the downloaded file has the same name as desired output (e.g. libmufiz.so), copy directly.
    # Otherwise attempt to extract and find the proper library inside.
    if [[ "$ARTIFACT" == *.so ]] || [[ "$ARTIFACT" == *.dylib ]] || [[ "$ARTIFACT" == *.dll ]]; then
        cp "$ARTIFACT" "$OUT_DIR/$OUT_NAME"
        chmod 755 "$OUT_DIR/$OUT_NAME"
        info "Installed $OUT_DIR/$OUT_NAME from prebuilt artifact."
        exit 0
    fi

    extract_and_find_lib "$ARTIFACT" "$OUT_DIR/$OUT_NAME" || die "Failed to extract & locate library in artifact."
    chmod 755 "$OUT_DIR/$OUT_NAME"
    info "Installed $OUT_DIR/$OUT_NAME from archive."
    exit 0
fi

# ---------- build from source ----------
if [[ -z "$GIT_URL" ]]; then
    die "No MUFIZ_PREBUILT_URL or MUFIZ_GIT_URL provided. Set MUFIZ_PREBUILT_URL to download a binary, or MUFIZ_GIT_URL to build from source."
fi

info "Cloning mufiz repository from: $GIT_URL (tag: $TAG)"
git clone --depth 1 --branch "$TAG" "$GIT_URL" "$TMPDIR/mufiz-src" || die "Git clone failed"

pushd "$TMPDIR/mufiz-src" >/dev/null || die "Cannot enter source dir"

# If explicit build command provided, use it.
if [[ -n "$BUILD_CMD" ]]; then
    info "Using provided build command: $BUILD_CMD"
    # Run build in a shell to support complex commands
    bash -lc "$BUILD_CMD" || die "Custom build command failed"
else
    # Try Zig first (preferred for this runtime)
    if command -v zig >/dev/null 2>&1; then
        info "Found 'zig' in PATH. Attempting Zig build..."
        if [[ -n "$TARGET" ]]; then
            info "Building for target: $TARGET"
            zig build -Dtarget="$TARGET" || die "Zig build failed (target $TARGET)"
        else
            zig build || die "Zig build failed"
        fi
    elif [[ -f "CMakeLists.txt" ]]; then
        if command -v cmake >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
            info "CMake build detected; running cmake/make"
            mkdir -p build
            pushd build >/dev/null
            cmake .. || die "cmake configure failed"
            cmake --build . || die "cmake build failed"
            popd >/dev/null
        else
            die "CMake project detected but cmake or make not available"
        fi
    elif [[ -f "Makefile" ]]; then
        if command -v make >/dev/null 2>&1; then
            info "Makefile found; running make"
            make || die "make failed"
        else
            die "Makefile found but 'make' is not available"
        fi
    else
        die "No recognized build system found and no custom MUFIZ_BUILD_CMD provided. Install Zig or provide a prebuilt artifact."
    fi
fi

# Search for built library artifacts in common locations
info "Searching for built library artifacts..."
BUILD_LIB="$(find_built_lib "$PWD" || true)"

if [[ -z "$BUILD_LIB" ]]; then
    # Look in typical output folders (zig-out/lib, build, build/lib, lib)
    for d in zig-out/lib build lib out; do
        if [[ -d "$d" ]]; then
            candidate="$(find_built_lib "$d" || true)"
            if [[ -n "$candidate" ]]; then
                BUILD_LIB="$candidate"
                break
            fi
        fi
    done
fi

if [[ -z "$BUILD_LIB" ]]; then
    err "Could not locate libmufiz in build outputs. Here are files near source root for debugging:"
    find . -maxdepth 3 -type f -name 'libmufiz*' -print || true
    die "Build finished but library not found"
fi

info "Found built library: $BUILD_LIB"
cp "$BUILD_LIB" "$OUT_DIR/$OUT_NAME"
chmod 755 "$OUT_DIR/$OUT_NAME"
info "Successfully installed $OUT_DIR/$OUT_NAME"

popd >/dev/null

# Final sanity checks
if [[ ! -f "$OUT_DIR/$OUT_NAME" ]]; then
    die "Expected library not found at $OUT_DIR/$OUT_NAME after build/install"
fi

info "libmufiz ready at: $OUT_DIR/$OUT_NAME (arch: $ARCH, OS: $OS)"
exit 0
