# Ferrufi Scripts

This directory contains helper scripts for building and managing the Ferrufi project.

## Scripts

### `copy_mufiz_dylib.sh`

**Purpose**: Copies the Mufi runtime library (`libmufiz.dylib`) to Swift build output directories.

**Usage**:
```bash
./scripts/copy_mufiz_dylib.sh
```

**What it does**:
1. Locates `Sources/CMufi/libmufiz.dylib` in the repository
2. Copies it to various build directories:
   - `.build/debug/`
   - `.build/release/`
   - `.build/arm64-apple-macosx/debug/`
   - `.build/arm64-apple-macosx/release/`
   - `.build/x86_64-apple-macosx/debug/`
   - `.build/x86_64-apple-macosx/release/`
   - `.build/` (root)

**When to run**:
- Before building for the first time
- After cleaning the build directory (`swift package clean`)
- When the dylib is updated
- If you encounter "Library not loaded" runtime errors

**Example workflow**:
```bash
# Clean build
swift package clean
./scripts/copy_mufiz_dylib.sh
swift build

# Run tests
./scripts/copy_mufiz_dylib.sh
swift test

# Build for release
./scripts/copy_mufiz_dylib.sh
swift build -c release
```

**Error handling**:
- Exits with error if `libmufiz.dylib` is not found
- Continues gracefully if target directories don't exist yet
- Non-zero exit code indicates failure to find the source dylib

**Integration**:
- Called automatically by `build_macos.sh` during DMG packaging
- Should be run manually for local development builds
- Safe to run multiple times (idempotent)

### `build_dmg_local.sh`

**Purpose**: Build Ferrufi as a macOS .app bundle and package it in a DMG file for local distribution.

**Usage**:
```bash
# Basic build (auto-detects version from git)
./scripts/build_dmg_local.sh

# Build with specific version
./scripts/build_dmg_local.sh --version 1.0.0

# Build debug version
./scripts/build_dmg_local.sh --debug

# Skip code signing
./scripts/build_dmg_local.sh --no-codesign

# Keep staging directory for inspection
./scripts/build_dmg_local.sh --keep-staging
```

**What it does**:
1. ✓ Detects version from git (tag or commit SHA)
2. ✓ Verifies libmufiz.dylib exists and checks architecture
3. ✓ Builds the app using Swift Package Manager (release by default)
4. ✓ Creates a proper .app bundle structure
5. ✓ Bundles libmufiz.dylib into Contents/Frameworks/
6. ✓ Fixes dylib install names and rpaths
7. ✓ Creates Info.plist with proper bundle information
8. ✓ Optionally code signs the app and dylib
9. ✓ Creates a compressed DMG with Applications symlink
10. ✓ Outputs: `Ferrufi-<VERSION>-macos.dmg`

**Options**:
- `--version <ver>` - Set explicit version (default: auto-detect)
- `--debug` - Build debug configuration instead of release
- `--no-codesign` - Skip code signing
- `--keep-staging` - Keep temporary DMG staging directory
- `-h, --help` - Show help message

**Environment variables**:
- `CODESIGN_IDENTITY` - Code signing identity (e.g. "Developer ID Application: Your Name")

**When to run**:
- To create a distributable DMG for local testing
- Before releasing a new version
- To test the app bundle structure
- When you need a .dmg file to share with others

**Output**:
- DMG file in project root: `Ferrufi-<VERSION>-macos.dmg`
- Self-contained app with bundled libmufiz.dylib
- Typical size: ~3-5 MB compressed

**Example workflow**:
```bash
# Build a DMG for distribution
./scripts/build_dmg_local.sh --version 1.0.0

# Open and test the DMG
open Ferrufi-1.0.0-macos.dmg

# Drag Ferrufi.app to Applications and test
```

**Note**: This script is optimized for local builds. For CI/CD and GitHub releases, use the main `build_macos.sh` script.

### `set_version.sh`

**Purpose**: Update the app version in `Version.swift` for releases and builds.

**Usage**:
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

# Show help
./scripts/set_version.sh --help
```

**What it does**:
1. ✓ Reads current version from `Sources/Ferrufi/Version.swift`
2. ✓ Updates version numbers (major, minor, patch)
3. ✓ Validates version format (semantic versioning)
4. ✓ Provides helpful next-step suggestions
5. ✓ Safe - validates input before making changes

**When to use**:
- Before building a release DMG
- When preparing a new version for distribution
- Before tagging a release in git
- When following semantic versioning workflow

**Semantic Versioning Guide**:
- **Major** (`--major`): Breaking changes (1.0.0 → 2.0.0)
- **Minor** (`--minor`): New features (1.0.0 → 1.1.0)
- **Patch** (`--patch`): Bug fixes (1.0.0 → 1.0.1)

**Example workflow**:
```bash
# 1. Update version
./scripts/set_version.sh --minor

# 2. Build DMG (automatically uses new version)
./scripts/build_dmg_local.sh --no-codesign

# 3. Commit and tag
git commit -am "Bump version to 1.1.0"
git tag v1.1.0
git push && git push --tags
```

**Output**: Updates `Sources/Ferrufi/Version.swift` with new version numbers.

**Note**: The version in Version.swift is automatically used by `build_dmg_local.sh` when creating DMG files.

### `test_linking.sh`

**Purpose**: Comprehensive test script to verify that libmufiz linking is configured correctly.

**Usage**:
```bash
./scripts/test_linking.sh
```

**What it tests**:
1. ✓ Verifies `libmufiz.dylib` exists in `Sources/CMufi/`
2. ✓ Checks architecture of the dylib (arm64/x86_64)
3. ✓ Validates `copy_mufiz_dylib.sh` is executable
4. ✓ Runs the copy script successfully
5. ✓ Builds the project with Swift Package Manager
6. ✓ Verifies the executable is linked to libmufiz.dylib
7. ✓ Checks rpath configuration

**When to run**:
- After cloning the repository for the first time
- After making changes to linking configuration
- To diagnose linking issues
- As part of pre-commit validation
- Before creating a distribution build

**Example output**:
```
=== Ferrufi libmufiz Linking Test ===

✓ Test 1: Checking libmufiz.dylib exists...
  ✓ Found: Sources/CMufi/libmufiz.dylib
...
✓ Test 6: Checking rpath configuration...
  ✓ Rpath is configured

=== All Tests Passed! ===
```

**Exit codes**:
- `0`: All tests passed
- `1`: One or more tests failed

**Troubleshooting**:
If tests fail, the script will show which test failed and provide diagnostic information. Common failures:
- Missing dylib: Build or obtain libmufiz.dylib from Mufi-lang repository
- Build failure: Check Swift version compatibility (requires Swift 6.2+)
- Linking failure: Run `./scripts/copy_mufiz_dylib.sh` and rebuild

## Why This Script is Needed

Swift Package Manager and Xcode need to find `libmufiz.dylib` at runtime. By default, the dylib is located in `Sources/CMufi/`, but Swift's runtime library search paths look in the build output directories.

This script bridges that gap by copying the dylib to where the executable expects to find it during development and testing.

For distribution builds (DMG), the `build_macos.sh` script bundles the dylib into the app's `Contents/Frameworks/` directory and sets appropriate rpath references.

## Architecture Support

The current `libmufiz.dylib` is built for **arm64** (Apple Silicon). If you need to support Intel Macs, you'll need to:

1. Build an x86_64 version of the dylib
2. Create a universal binary:
   ```bash
   lipo -create libmufiz_arm64.dylib libmufiz_x86_64.dylib \
        -output libmufiz.dylib
   ```
3. Replace `Sources/CMufi/libmufiz.dylib` with the universal binary
4. Run `./scripts/copy_mufiz_dylib.sh` to update build directories

## Troubleshooting

### "ERROR: libmufiz.dylib not found"

**Cause**: The source dylib is missing from `Sources/CMufi/`

**Solution**: 
1. Verify the file exists: `ls -l Sources/CMufi/libmufiz.dylib`
2. If missing, build or obtain the dylib from the Mufi-lang repository
3. Ensure it's named exactly `libmufiz.dylib`

### "failed to copy to X, continuing..."

**Cause**: Target directory doesn't exist yet (expected for fresh builds)

**Impact**: Non-critical. The directory will be created on first build, then run the script again.

**Solution**: Build once (`swift build`) then re-run the script.

### Script has no effect

**Cause**: Script may not be executable

**Solution**: 
```bash
chmod +x scripts/copy_mufiz_dylib.sh
chmod +x scripts/build_dmg_local.sh
```

## Building a DMG

To create a distributable DMG file:

```bash
# Quick build (no code signing)
./scripts/build_dmg_local.sh --no-codesign

# Build with specific version
./scripts/build_dmg_local.sh --version 1.0.0

# Build with code signing (if you have a Developer ID)
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
./scripts/build_dmg_local.sh
```

The DMG will be created in the project root directory.

## Quick Validation

To quickly validate your setup is correct:

```bash
# Run all validation steps
./scripts/test_linking.sh

# If all tests pass, you're ready to develop!
swift run FerrufiApp
```

## Adding New Scripts

When adding new helper scripts to this directory:

1. Name them descriptively (`verb_noun.sh` pattern)
2. Add executable permissions: `chmod +x scripts/your_script.sh`
3. Include usage comments at the top of the script
4. Document the script in this README
5. Handle errors gracefully
6. Test on a clean repository
7. Add tests to `test_linking.sh` if applicable
8. Use proper error handling and cleanup (trap handlers)
9. Provide colored output for better UX
10. Include a --help option

## Versioning

Ferrufi uses a centralized versioning system with `Version.swift`:

```bash
# Check current version
./scripts/set_version.sh --show

# Update for a patch release
./scripts/set_version.sh --patch

# Update for a minor release (new features)
./scripts/set_version.sh --minor

# Update for a major release (breaking changes)
./scripts/set_version.sh --major
```

After updating the version:
1. Build DMG: `./scripts/build_dmg_local.sh`
2. The DMG will be named: `Ferrufi-X.Y.Z-macos.dmg`
3. Tag the release: `git tag vX.Y.Z`

See [Versioning Guide](../docs/VERSIONING.md) for complete documentation.

## Related Documentation

- [Versioning Guide](../docs/VERSIONING.md) - Complete version management guide
- [Linking Guide](../docs/LIBMUFIZ_LINKING.md) - Comprehensive linking documentation
- [Quick Start](../docs/QUICK_START.md) - Getting started guide
- [Changelog](../docs/CHANGELOG_LINKING_FIX.md) - Recent linking fixes

---

**Maintained by**: Ferrufi Development Team  
**Last updated**: 2024