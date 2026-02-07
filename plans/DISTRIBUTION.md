# Ferrufi Distribution Guide

This guide covers the different ways to build and distribute Ferrufi for macOS.

## Quick Start

For most use cases, we recommend using the standalone `.app` bundle:

```bash
# Build a distributable .app with zip archive
./scripts/build_app.sh --no-codesign --zip
```

This creates:
- `Ferrufi.app` - Ready-to-use application
- `Ferrufi-X.Y.Z-macos.zip` - Compressed archive for easy sharing

## Distribution Methods Comparison

### Standalone .app Bundle (Recommended)

**When to use:**
- Quick distribution to users
- Sharing via cloud storage (Dropbox, Google Drive, etc.)
- Direct downloads from your website
- Most common use case

**Advantages:**
✓ Simple to distribute (just share the zip file)  
✓ Smaller file size when compressed (~3 MB)  
✓ Users can directly copy to Applications  
✓ No DMG mounting/unmounting required  
✓ Faster build time  
✓ Easier to update and redistribute  
✓ Works great with cloud storage services  

**How to build:**
```bash
# Basic build
./scripts/build_app.sh --no-codesign

# With version and zip
./scripts/build_app.sh --version 1.0.0 --zip

# To Desktop for easy access
./scripts/build_app.sh --zip --output ~/Desktop
```

**Distribution steps:**
1. Build the app with `--zip` option
2. Upload `Ferrufi-X.Y.Z-macos.zip` to your distribution channel
3. Users download and unzip
4. Users drag `Ferrufi.app` to Applications

---

### DMG Image

**When to use:**
- Professional releases
- App Store-style distribution
- When you want a branded installer experience
- Custom installation workflows

**Advantages:**
✓ Professional appearance  
✓ Can include custom background and layout  
✓ Shows Applications folder symlink for easy installation  
✓ Industry-standard format  
✓ Self-contained installation package  

**How to build:**
```bash
# Basic DMG build
./scripts/build_dmg_local.sh --no-codesign

# With specific version
./scripts/build_dmg_local.sh --version 1.0.0
```

**Distribution steps:**
1. Build DMG with `build_dmg_local.sh`
2. Upload `Ferrufi-X.Y.Z-macos.dmg` to your distribution channel
3. Users download and open DMG
4. Users drag Ferrufi to Applications folder
5. Users eject DMG

---

## Feature Comparison

| Feature | .app Bundle | DMG |
|---------|-------------|-----|
| File size (compressed) | ~3 MB | ~4-5 MB |
| Build time | Fast | Slightly slower |
| User installation steps | 1-2 steps | 3-4 steps |
| Professional appearance | Standard | Customizable |
| Code signing support | ✓ | ✓ |
| Notarization support | ✓ | ✓ |
| Customizable layout | ✗ | ✓ |
| Cloud storage friendly | ✓✓ | ✓ |
| Direct execution | ✓ | After mount |

## Installation Notes

All builds are unsigned. Users will need to:
- Right-click → Open (first time only)
- Or allow in System Settings → Privacy & Security
- Or run: `xattr -cr /Applications/Ferrufi.app`

## Versioning

Both methods automatically detect version from `Version.swift`:

```bash
# Update version first
./scripts/set_version.sh --minor  # or --patch, --major

# Then build
./scripts/build_app.sh --zip
```

The version will be embedded in:
- Filename: `Ferrufi-1.2.3-macos.zip`
- Info.plist: `CFBundleVersion` and `CFBundleShortVersionString`
- About dialog (shown in the app)

## Distribution Channels

### GitHub Releases (Recommended)

Upload the `.zip` or `.dmg` as a release asset:

```bash
# 1. Set version
./scripts/set_version.sh 1.0.0

# 2. Build
./scripts/build_app.sh --zip

# 3. Create GitHub release
gh release create v1.0.0 \
  Ferrufi-1.0.0-macos.zip \
  --title "Ferrufi v1.0.0" \
  --notes "Release notes here"
```

### Direct Download

Host on your website:

```html
<a href="https://yoursite.com/downloads/Ferrufi-1.0.0-macos.zip">
  Download Ferrufi for macOS
</a>
```

### Cloud Storage

Share via Dropbox, Google Drive, iCloud, etc.:

1. Upload `Ferrufi-X.Y.Z-macos.zip`
2. Generate a share link
3. Distribute the link

## Installation Instructions for Users

### From .zip File

1. Download `Ferrufi-X.Y.Z-macos.zip`
2. Double-click to extract `Ferrufi.app`
3. Drag `Ferrufi.app` to Applications folder
4. First launch: Right-click → Open (if unsigned)

### From DMG

1. Download `Ferrufi-X.Y.Z-macos.dmg`
2. Double-click to open
3. Drag `Ferrufi` to Applications folder
4. Eject the DMG
5. First launch: Right-click → Open (if unsigned)

## Architecture Support

Current builds support **Apple Silicon (arm64)** only.

### Building Universal Binary

To support both Apple Silicon and Intel Macs:

1. Build x86_64 version of `libmufiz.dylib`
2. Create universal binary:
   ```bash
   lipo -create \
     Sources/CMufi/libmufiz_arm64.dylib \
     Sources/CMufi/libmufiz_x86_64.dylib \
     -output Sources/CMufi/libmufiz.dylib
   ```
3. Build as normal - the app will run on both architectures

## Troubleshooting

### "App is damaged and can't be opened"

**Cause:** Gatekeeper blocking unsigned apps

**Solution:**
```bash
xattr -cr /Applications/Ferrufi.app
```

Or instruct users to right-click → Open.

### "Library not loaded: libmufiz.dylib"

**Cause:** Missing dylib or incorrect rpath

**Solution:** Rebuild with the official scripts:
```bash
./scripts/build_app.sh --no-codesign
```

### Build fails with linking errors

**Cause:** Missing or incompatible `libmufiz.dylib`

**Solution:**
```bash
# Verify dylib exists
ls -l Sources/CMufi/libmufiz.dylib

# Check architecture
lipo -info Sources/CMufi/libmufiz.dylib

# Run linking tests
./scripts/test_linking.sh
```

## Best Practices

### For Development Builds

```bash
# Quick build for testing
./scripts/build_app.sh
```

### For Beta Testing

```bash
# Versioned zip for beta testers
./scripts/set_version.sh 1.0.0-beta.1
./scripts/build_app.sh --zip
```

### For Production Releases

```bash
# Versioned release
./scripts/set_version.sh 1.0.0
./scripts/build_app.sh --zip

# Or DMG for professional distribution
./scripts/build_dmg_local.sh
```

### For CI/CD

Use the GitHub Actions workflows in `.github/workflows/`:

- `experimental-release.yml` - Automatic builds on push
- `macos-dmg-release.yml` - Official releases on tags

## Quick Reference

| Task | Command |
|------|---------|
| Build .app | `./scripts/build_app.sh` |
| Build .app + zip | `./scripts/build_app.sh --zip` |
| Build DMG | `./scripts/build_dmg_local.sh` |
| Set version | `./scripts/set_version.sh X.Y.Z` |
| Test linking | `./scripts/test_linking.sh` |
| Check current version | `./scripts/set_version.sh --show` |

## Related Documentation

- [Distribution Quick Start](../DISTRIBUTION_QUICKSTART.md) - Quick reference guide
- [Linking Guide](./LIBMUFIZ_LINKING.md) - Comprehensive linking documentation
- [Versioning Guide](./VERSIONING.md) - Version management guide
- [Scripts README](../scripts/README.md) - All available scripts
- [Workflows Documentation](../.github/workflows/README.md) - CI/CD setup

## Summary

**For most users:** Use `build_app.sh --zip` to create a simple, distributable zip file.

**For professional releases:** Use `build_dmg_local.sh` to create a branded DMG installer.

**For testing:** Use `build_app.sh` for quick builds.

---

**Questions?** Check the [troubleshooting section](#troubleshooting) or file an issue on GitHub.