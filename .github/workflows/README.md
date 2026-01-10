# GitHub Workflows Documentation

This directory contains GitHub Actions workflows for automating builds, testing, and releases of Ferrufi.

## Workflows

### 1. `experimental-release.yml` - Experimental Builds

**Trigger:**
- Automatically on push to `main` or `develop` branches
- Manually via workflow dispatch

**Purpose:**
Creates experimental/development builds for testing new features and changes.

**What it does:**
1. ✓ Detects Swift version from Package.swift
2. ✓ Sets up correct Swift toolchain
3. ✓ Reads version from `Sources/Ferrufi/Version.swift`
4. ✓ Generates experimental version: `0.0.0-exp.123.abc1234`
5. ✓ Runs linking validation tests
6. ✓ Builds unsigned DMG
7. ✓ Creates/updates `experimental` GitHub release
8. ✓ Uploads DMG as workflow artifact (30 days retention)

**Output:**
- DMG: `Ferrufi-0.0.0-exp.{run_number}.{commit}-macos.dmg`
- Release: https://github.com/{owner}/{repo}/releases/tag/experimental
- Artifact: Available in workflow run

**Manual Trigger:**
```bash
# Via GitHub CLI
gh workflow run experimental-release.yml

# With version override
gh workflow run experimental-release.yml -f version_override=0.1.0-beta1
```

**Usage:**
- Automatically builds on every push to main/develop
- Download from experimental release for testing
- Not code-signed (users need to right-click → Open)
- Automatically overwrites previous experimental release

---

### 2. `macos-dmg-release.yml` - Official Releases

**Trigger:**
- Automatically on git tag push: `v*.*.*` (e.g., `v1.0.0`)
- Manually via workflow dispatch with version input

**Purpose:**
Creates official release builds with proper versioning and GitHub releases.

**What it does:**
1. ✓ Detects version from git tag or manual input
2. ✓ Sets up correct Swift toolchain
3. ✓ Runs linking validation tests
4. ✓ Builds DMG (optionally code-signed)
5. ✓ Creates GitHub release with release notes
6. ✓ Uploads DMG to release
7. ✓ Uploads DMG as workflow artifact (90 days retention)

**Output:**
- DMG: `Ferrufi-{version}-macos.dmg`
- Release: https://github.com/{owner}/{repo}/releases/tag/v{version}
- Artifact: Available in workflow run

**Manual Trigger:**
```bash
# Via GitHub CLI
gh workflow run macos-dmg-release.yml -f version=1.0.0

# With code signing
gh workflow run macos-dmg-release.yml -f version=1.0.0 -f codesign=true
```

**Tag-based Release:**
```bash
# Update version in Version.swift
./scripts/set_version.sh 1.0.0

# Commit and tag
git add Sources/Ferrufi/Version.swift
git commit -m "Release version 1.0.0"
git tag v1.0.0
git push origin main --tags

# Workflow triggers automatically and creates release
```

---

## Release Process

### Experimental Build (Development)

For testing and development builds:

```bash
# 1. Push to main or develop
git push origin main

# 2. Workflow runs automatically
# 3. Download from: https://github.com/{owner}/{repo}/releases/tag/experimental
```

**Experimental builds:**
- ✓ Auto-generated version: `0.0.0-exp.{run_number}.{commit}`
- ✓ Not code-signed
- ✓ Overwrites previous experimental release
- ✓ For testing only

---

### Official Release

For stable, versioned releases:

```bash
# 1. Update version
./scripts/set_version.sh 1.0.0

# 2. Update CHANGELOG.md
# Add release notes for version 1.0.0

# 3. Commit version bump
git add Sources/Ferrufi/Version.swift CHANGELOG.md
git commit -m "Release version 1.0.0"

# 4. Create and push tag
git tag v1.0.0
git push origin main
git push origin v1.0.0

# 5. Workflow runs automatically
# 6. Check release at: https://github.com/{owner}/{repo}/releases/tag/v1.0.0
```

**Official releases:**
- ✓ Semantic versioning: `1.0.0`
- ✓ Optionally code-signed
- ✓ Creates permanent GitHub release
- ✓ Includes release notes
- ✓ For distribution

---

## Code Signing

### Setup Code Signing (Optional)

To enable code signing for releases:

1. **Generate signing certificate** (Apple Developer account required)
   ```bash
   # Create Developer ID Application certificate in Keychain
   ```

2. **Add secret to GitHub**
   - Go to: Settings → Secrets and variables → Actions
   - Add secret: `CODESIGN_IDENTITY`
   - Value: `"Developer ID Application: Your Name (TEAMID)"`

3. **Enable in workflow**
   ```bash
   gh workflow run macos-dmg-release.yml \
     -f version=1.0.0 \
     -f codesign=true
   ```

**Note:** Experimental builds are never code-signed (by design).

---

## Environment Variables

Both workflows use these environment variables:

| Variable | Source | Purpose |
|----------|--------|---------|
| `GITHUB_TOKEN` | Auto-provided | Create/update releases |
| `CODESIGN_IDENTITY` | Secret (optional) | Code signing |
| Swift version | Package.swift | Toolchain setup |
| App version | Version.swift | DMG naming |

---

## Artifacts

### Workflow Artifacts

All builds upload DMG as workflow artifact:

- **Experimental:** 30 days retention
- **Release:** 90 days retention

Download from: Actions → Workflow Run → Artifacts

### Release Assets

- **Experimental:** Single DMG in experimental release (auto-overwrites)
- **Official:** DMG in versioned release (permanent)

---

## Requirements

### System Requirements

- **Runner:** `macos-latest`
- **Swift:** Auto-detected from Package.swift (currently 6.2)
- **macOS:** 14.0+ required for building

### Repository Requirements

- ✓ `Sources/Ferrufi/Version.swift` - Version source
- ✓ `Sources/CMufi/libmufiz.dylib` - Mufi runtime
- ✓ `scripts/build_dmg_local.sh` - Build script
- ✓ `scripts/test_linking.sh` - Validation script

---

## Troubleshooting

### Build Fails: "libmufiz.dylib not found"

**Solution:**
Ensure `Sources/CMufi/libmufiz.dylib` is committed to repository:
```bash
git add Sources/CMufi/libmufiz.dylib
git commit -m "Add libmufiz.dylib"
git push
```

### Build Fails: "Swift version mismatch"

**Solution:**
Update swift-tools-version in Package.swift:
```swift
// swift-tools-version: 6.2
```

### DMG Not Appearing in Release

**Problem:** Workflow succeeds but no DMG in release

**Solution:**
1. Check GITHUB_TOKEN has `contents: write` permission
2. Verify workflow permissions in Settings → Actions
3. Check workflow logs for errors

### Code Signing Fails

**Problem:** Signing fails even with CODESIGN_IDENTITY set

**Solution:**
1. Verify identity string format: `"Developer ID Application: Name (ID)"`
2. Check certificate is valid and not expired
3. For testing, use `--no-codesign` flag

---

## Workflow Status

Check workflow status:

```bash
# List recent workflow runs
gh run list --workflow=experimental-release.yml

# View specific run
gh run view {run-id}

# Watch live
gh run watch
```

---

## Manual Workflow Dispatch

### Via GitHub Web UI

1. Go to: Actions → Select workflow
2. Click "Run workflow"
3. Select branch and fill inputs
4. Click "Run workflow"

### Via GitHub CLI

```bash
# Experimental build
gh workflow run experimental-release.yml

# Official release
gh workflow run macos-dmg-release.yml \
  -f version=1.0.0 \
  -f codesign=false
```

---

## Best Practices

### For Experimental Builds

- ✓ Push frequently to main/develop for testing
- ✓ Download from experimental release
- ✓ Test before official release
- ✓ Don't rely on experimental builds for distribution

### For Official Releases

- ✓ Update version in Version.swift first
- ✓ Update CHANGELOG.md with changes
- ✓ Test experimental build first
- ✓ Use semantic versioning
- ✓ Tag with `v` prefix: `v1.0.0`
- ✓ Write clear release notes

### General

- ✓ Always run `./scripts/test_linking.sh` locally first
- ✓ Verify libmufiz.dylib architecture matches target
- ✓ Keep Version.swift in sync with git tags
- ✓ Monitor workflow runs for failures

---

## Workflow Outputs

### Experimental Release Output

```
✅ Experimental DMG Build Complete

Build Information:
- Version: 0.0.0-exp.123.abc1234
- DMG File: Ferrufi-0.0.0-exp.123.abc1234-macos.dmg
- Swift Version: 6.2
- Build Number: #123
- Commit: abc1234

Download:
- Experimental Release
- Workflow Artifacts
```

### Official Release Output

```
✅ Release Build Complete

Release Information:
- Version: 1.0.0
- DMG File: Ferrufi-1.0.0-macos.dmg
- DMG Size: 3.3M
- Swift Version: 6.2
- Code Signed: No

Downloads:
- Workflow Artifact
- GitHub Release
```

---

## Related Documentation

- [Versioning Guide](../../docs/VERSIONING.md) - Version management
- [Build Scripts](../../scripts/README.md) - Local build documentation
- [Quick Start](../../docs/QUICK_START.md) - Development setup

---

**Last Updated:** 2024
**Workflows Version:** 2.0
**Status:** ✅ Production Ready