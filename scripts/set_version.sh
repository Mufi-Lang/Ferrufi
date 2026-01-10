#!/bin/zsh
#
# set_version.sh — Update the app version in Version.swift
#
# Usage:
#   ./scripts/set_version.sh <major>.<minor>.<patch>
#   ./scripts/set_version.sh --major       # Bump major version (1.0.0 -> 2.0.0)
#   ./scripts/set_version.sh --minor       # Bump minor version (1.0.0 -> 1.1.0)
#   ./scripts/set_version.sh --patch       # Bump patch version (1.0.0 -> 1.0.1)
#   ./scripts/set_version.sh --show        # Show current version
#
# Examples:
#   ./scripts/set_version.sh 1.2.3
#   ./scripts/set_version.sh --minor
#   ./scripts/set_version.sh --show
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper functions
info()  { printf "${BLUE}▶${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
error() { printf "${RED}✗${NC} %s\n" "$*"; >&2 }

# Get to repository root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
VERSION_FILE="$REPO_ROOT/Sources/Ferrufi/Version.swift"

# Check if Version.swift exists
if [ ! -f "$VERSION_FILE" ]; then
    error "Version.swift not found at: $VERSION_FILE"
    exit 1
fi

# Read current version
get_current_version() {
    local major=$(grep -E '^\s*public static let major = ' "$VERSION_FILE" | sed 's/.*= //' | tr -d ' ')
    local minor=$(grep -E '^\s*public static let minor = ' "$VERSION_FILE" | sed 's/.*= //' | tr -d ' ')
    local patch=$(grep -E '^\s*public static let patch = ' "$VERSION_FILE" | sed 's/.*= //' | tr -d ' ')
    echo "$major.$minor.$patch"
}

# Update version in file
update_version() {
    local new_major=$1
    local new_minor=$2
    local new_patch=$3

    info "Updating version to $new_major.$new_minor.$new_patch"

    # Use sed to replace the version numbers
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version of sed
        sed -i '' "s/public static let major = .*/public static let major = $new_major/" "$VERSION_FILE"
        sed -i '' "s/public static let minor = .*/public static let minor = $new_minor/" "$VERSION_FILE"
        sed -i '' "s/public static let patch = .*/public static let patch = $new_patch/" "$VERSION_FILE"
    else
        # GNU sed
        sed -i "s/public static let major = .*/public static let major = $new_major/" "$VERSION_FILE"
        sed -i "s/public static let minor = .*/public static let minor = $new_minor/" "$VERSION_FILE"
        sed -i "s/public static let patch = .*/public static let patch = $new_patch/" "$VERSION_FILE"
    fi

    success "Version updated in $VERSION_FILE"
}

# Parse current version components
parse_version() {
    local version=$1
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local patch=$(echo "$version" | cut -d. -f3)
    echo "$major $minor $patch"
}

# Show usage
print_usage() {
    cat <<USAGE
${BOLD}Usage:${NC}
  $0 <major>.<minor>.<patch>    Set specific version
  $0 --major                     Bump major version (1.0.0 -> 2.0.0)
  $0 --minor                     Bump minor version (1.0.0 -> 1.1.0)
  $0 --patch                     Bump patch version (1.0.0 -> 1.0.1)
  $0 --show                      Show current version
  $0 -h, --help                  Show this help

${BOLD}Examples:${NC}
  $0 1.2.3          # Set version to 1.2.3
  $0 --minor        # Bump minor version
  $0 --show         # Show current version

${BOLD}Current version:${NC} $(get_current_version)
USAGE
}

# Main logic
if [ $# -eq 0 ]; then
    error "No arguments provided"
    print_usage
    exit 1
fi

CURRENT_VERSION=$(get_current_version)
read -r CURRENT_MAJOR CURRENT_MINOR CURRENT_PATCH <<< $(parse_version "$CURRENT_VERSION")

case "$1" in
    -h|--help)
        print_usage
        exit 0
        ;;

    --show)
        info "Current version: ${BOLD}$CURRENT_VERSION${NC}"
        exit 0
        ;;

    --major)
        NEW_MAJOR=$((CURRENT_MAJOR + 1))
        NEW_MINOR=0
        NEW_PATCH=0
        info "Bumping major version: $CURRENT_VERSION -> $NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
        update_version $NEW_MAJOR $NEW_MINOR $NEW_PATCH
        success "Version bumped to $NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
        ;;

    --minor)
        NEW_MAJOR=$CURRENT_MAJOR
        NEW_MINOR=$((CURRENT_MINOR + 1))
        NEW_PATCH=0
        info "Bumping minor version: $CURRENT_VERSION -> $NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
        update_version $NEW_MAJOR $NEW_MINOR $NEW_PATCH
        success "Version bumped to $NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
        ;;

    --patch)
        NEW_MAJOR=$CURRENT_MAJOR
        NEW_MINOR=$CURRENT_MINOR
        NEW_PATCH=$((CURRENT_PATCH + 1))
        info "Bumping patch version: $CURRENT_VERSION -> $NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
        update_version $NEW_MAJOR $NEW_MINOR $NEW_PATCH
        success "Version bumped to $NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
        ;;

    *)
        # Assume it's a version string like "1.2.3"
        NEW_VERSION=$1
        if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            error "Invalid version format: $NEW_VERSION"
            error "Expected format: major.minor.patch (e.g., 1.2.3)"
            exit 1
        fi

        read -r NEW_MAJOR NEW_MINOR NEW_PATCH <<< $(parse_version "$NEW_VERSION")
        info "Setting version: $CURRENT_VERSION -> $NEW_VERSION"
        update_version $NEW_MAJOR $NEW_MINOR $NEW_PATCH
        success "Version set to $NEW_VERSION"
        ;;
esac

# Suggest next steps
echo ""
info "${BOLD}Next steps:${NC}"
echo "  1. Review changes: ${BLUE}git diff $VERSION_FILE${NC}"
echo "  2. Build DMG:      ${BLUE}./scripts/build_dmg_local.sh${NC}"
echo "  3. Commit:         ${BLUE}git commit -am \"Bump version to $(get_current_version)\"${NC}"
echo "  4. Tag release:    ${BLUE}git tag v$(get_current_version)${NC}"
echo "  5. Push:           ${BLUE}git push && git push --tags${NC}"

exit 0
