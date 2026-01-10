# Ferrufi Versioning Guide

## Overview

Ferrufi uses a centralized versioning system based on a `Version.swift` file. This guide explains how to manage versions for releases, DMG builds, and development.

## Version Management

### Current Version Location

The single source of truth for the app version is:

```
Sources/Ferrufi/Version.swift
```

This file contains:
```swift
public struct AppVersion {
    public static let major = 1    // Major version
    public static let minor = 0    // Minor version
    public static let patch = 0    // Patch version
    
    public static var versionString: String {
        return "\(major).\(minor).\(patch)"
    }
}
```

### Why Version.swift?

Swift Package Manager (`Package.swift`) **does not support a version field** for executables. Instead, we use:

1. **Version.swift** - Source of truth in code
2. **Git tags** - For release management
3. **Info.plist** - Generated automatically by build scripts

This approach provides:
- ✅ Single source of truth
- ✅ Compile-time version access
- ✅ Automatic DMG versioning
- ✅ Type-safe version comparisons

## Semantic Versioning

Ferrufi follows [Semantic Versioning 2.0.0](https://semver.org/):

**Format:** `MAJOR.MINOR.PATCH`

- **MAJOR** - Incompatible API changes, major rewrites
- **MINOR** - New features, backward-compatible
- **PATCH** - Bug fixes, backward-compatible

### Version Number Guidelines

| Version Change | When to Use | Example |
|----------------|-------------|---------|
| **Major (X.0.0)** | Breaking changes, major redesign | 1.0.0 → 2.0.0 |
| **Minor (1.X.0)** | New features, no breaking changes | 1.0.0 → 1.1.0 |
| **Patch (1.0.X)** | Bug fixes, minor improvements | 1.0.0 → 1.0.1 |

### Examples

```
1.0.0  - Initial stable release
1.0.1  - Bug fix release
1.1.0  - New feature: Mufi REPL enhancements
1.2.0  - New feature: Advanced search
2.0.0  - Major update: Complete UI redesign
```

## How to Update Version

### Quick Commands

```bash
# Show current version
./scripts/set_version.sh --show

# Bump patch version (1.0.0 -> 1.0.1)
./scripts/set_version.sh --patch

# Bump minor version (1.0.0 -> 1.1.0)
./scripts/set_version.sh --minor

# Bump major version (1.0.0 -> 2.0.0)
./scripts/set_version.sh --major

# Set specific version
./scripts/set_version.sh 1.2.3
```

### Manual Update

Edit `Sources/Ferrufi/Version.swift`:

```swift
public struct AppVersion {
    public static let major = 1  // ← Change these
    public static let minor = 2  // ← numbers
    public static let patch = 3  // ← to update
}
```

## Release Workflow

### Standard Release Process

```bash
# 1. Update version
./scripts/set_version.sh 1.1.0

# 2. Review changes
git diff Sources/Ferrufi/Version.swift

# 3. Commit version bump
git add Sources/Ferrufi/Version.swift
git commit -m "Bump version to 1.1.0"

# 4. Build and test DMG
./scripts/build_dmg_local.sh --no-codesign
open Ferrufi-1.1.0-macos.dmg

# 5. Tag the release
git tag v1.1.0

# 6. Push to remote
git push origin main
git push origin v1.1.0
```

### Pre-release Versions

For beta/alpha releases, use git branch names or add suffix in commit message:

```bash
# Build from develop branch
git checkout develop
./scripts/build_dmg_local.sh --no-codesign
# Creates: Ferrufi-1.1.0-macos.dmg (from Version.swift)

# Or specify custom version
./scripts/build_dmg_local.sh --version 1.1.0-beta1 --no-codesign
```

## Using Version in Code

### Access Version Information

```swift
import Ferrufi

// Get version string
let version = AppVersion.versionString  // "1.0.0"

// Get short version
let short = AppVersion.shortVersionString  // "1.0.0"

// Get full version with app name
let full = AppVersion.fullVersionString  // "Ferrufi 1.0.0"

// Individual components
let major = AppVersion.major  // 1
let minor = AppVersion.minor  // 0
let patch = AppVersion.patch  // 0

// Copyright
let copyright = AppVersion.copyright  // "Copyright © 2024 Ferrufi Contributors"
```

### Version Comparison

```swift
// Check if current version is at least a specific version
if AppVersion.isAtLeast("1.2.0") {
    print("Version is 1.2.0 or higher")
}
```

### Display Version in UI

```swift
// In an About window
Text(AppVersion.fullVersionString)
    .font(.title)

Text(AppVersion.copyright)
    .font(.caption)
    .foregroundColor(.secondary)
```

## Build System Integration

### DMG Build Script

The `build_dmg_local.sh` script automatically:

1. Reads version from `Version.swift`
2. Falls back to git tags if Version.swift not found
3. Uses version in DMG filename: `Ferrufi-1.0.0-macos.dmg`
4. Writes version to `Info.plist` in app bundle

**Version precedence:**
1. `--version` flag (command line)
2. `Version.swift` (Sources/Ferrufi/Version.swift)
3. Git tag (latest `git describe --tags`)
4. Git commit SHA (fallback)
5. Timestamp (last resort)

### Info.plist Generation

The build script automatically creates `Info.plist` with:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1.0.0</string>
```

These values come from `Version.swift`.

## Git Tags

### Creating Tags

After updating the version in `Version.swift`, create a matching git tag:

```bash
# Standard tag format
git tag v1.0.0

# Annotated tag with message (recommended)
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tag to remote
git push origin v1.0.0

# Push all tags
git push --tags
```

### Tag Naming Convention

- Use `v` prefix: `v1.0.0` (not `1.0.0`)
- Match Version.swift exactly
- Use semantic versioning

**Examples:**
```
v1.0.0       - Release 1.0.0
v1.0.1       - Patch release
v1.1.0       - Minor release
v2.0.0       - Major release
```

## CI/CD Integration

### GitHub Actions

The build workflow automatically:
- Reads version from `Version.swift`
- Creates DMG with proper version
- Can tag releases automatically

Example workflow snippet:

```yaml
- name: Get version
  id: version
  run: |
    VERSION=$(./scripts/set_version.sh --show | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    echo "version=$VERSION" >> $GITHUB_OUTPUT

- name: Build DMG
  run: ./scripts/build_dmg_local.sh --no-codesign
```

### Version in Release Notes

When creating a GitHub release:

```bash
# Get current version
VERSION=$(./scripts/set_version.sh --show | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

# Create release with gh CLI
gh release create "v$VERSION" \
  --title "Ferrufi $VERSION" \
  --notes "Release notes here" \
  Ferrufi-$VERSION-macos.dmg
```

## Version History

Track version changes in `CHANGELOG.md`:

```markdown
# Changelog

## [1.1.0] - 2024-01-15

### Added
- New feature: Advanced search
- Mufi REPL improvements

### Fixed
- Bug fix: Memory leak in editor

## [1.0.0] - 2024-01-01

### Added
- Initial stable release
```

## Best Practices

### ✅ Do's

- ✅ Always update `Version.swift` before building a release
- ✅ Use `set_version.sh` script for consistency
- ✅ Create git tags matching the version
- ✅ Test the DMG before releasing
- ✅ Update CHANGELOG.md with changes
- ✅ Use semantic versioning
- ✅ Commit version bumps separately

### ❌ Don'ts

- ❌ Don't manually edit version numbers inconsistently
- ❌ Don't skip version bumps for releases
- ❌ Don't reuse version numbers
- ❌ Don't forget to tag releases in git
- ❌ Don't push untagged releases
- ❌ Don't use arbitrary version numbers

## Troubleshooting

### Version not detected

**Problem:** DMG uses git commit SHA instead of version from Version.swift

**Solution:**
```bash
# Check if Version.swift has correct format
cat Sources/Ferrufi/Version.swift | grep "public static let"

# Make sure version numbers are integers without quotes
public static let major = 1    # ✅ Correct
public static let major = "1"  # ❌ Wrong
```

### DMG has wrong version

**Problem:** Built DMG shows old version

**Solution:**
```bash
# Clean build
swift package clean

# Update version
./scripts/set_version.sh 1.2.0

# Build fresh DMG
./scripts/build_dmg_local.sh --no-codesign
```

### Git tag mismatch

**Problem:** Git tag doesn't match Version.swift

**Solution:**
```bash
# Check current version
./scripts/set_version.sh --show

# Delete incorrect tag
git tag -d v1.0.0
git push origin :refs/tags/v1.0.0

# Create correct tag
git tag v1.0.0
git push origin v1.0.0
```

## Quick Reference

### Commands

```bash
# Version management
./scripts/set_version.sh --show         # Show current version
./scripts/set_version.sh --patch        # Bump patch (1.0.0 -> 1.0.1)
./scripts/set_version.sh --minor        # Bump minor (1.0.0 -> 1.1.0)
./scripts/set_version.sh --major        # Bump major (1.0.0 -> 2.0.0)
./scripts/set_version.sh 1.2.3          # Set specific version

# Build with version
./scripts/build_dmg_local.sh            # Use Version.swift
./scripts/build_dmg_local.sh --version 1.2.3  # Override version

# Git tags
git tag v1.0.0                          # Create tag
git push origin v1.0.0                  # Push tag
git tag -l                              # List tags
```

### Files

- `Sources/Ferrufi/Version.swift` - Version source of truth
- `scripts/set_version.sh` - Version management script
- `scripts/build_dmg_local.sh` - DMG builder (reads version)
- `CHANGELOG.md` - Version history (manual)

## Release Checklist

- [ ] Update version in Version.swift
- [ ] Update CHANGELOG.md
- [ ] Commit changes: `git commit -m "Bump version to X.Y.Z"`
- [ ] Build DMG: `./scripts/build_dmg_local.sh`
- [ ] Test DMG installation and functionality
- [ ] Create git tag: `git tag vX.Y.Z`
- [ ] Push commits: `git push origin main`
- [ ] Push tags: `git push origin vX.Y.Z`
- [ ] Create GitHub release with DMG attached
- [ ] Update documentation if needed

---

**Version Management:** Keep it simple, keep it consistent! 🎯

**Questions?** Check `./scripts/set_version.sh --help` or review `Sources/Ferrufi/Version.swift`
