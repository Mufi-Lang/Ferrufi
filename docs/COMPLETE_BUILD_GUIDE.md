# Complete Build & Distribution Guide

## Overview

Ferrufi can be built and distributed in two ways:
1. **Standalone .app bundle** (recommended) - Simple, compact, easy to share
2. **DMG installer** (optional) - Professional installer experience

## Quick Reference

### Most Common Commands

```bash
# Unsigned build (testing)
./scripts/build_app.sh  --zip

# Signed build (distribution)
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM)"
./scripts/build_app.sh --zip

# DMG build
./scripts/build_dmg_local.sh
```

### File Size Comparison

- `.app` bundle: ~11 MB
- `.zip` archive: ~3 MB (compressed)
- `.dmg` image: ~4-5 MB

## Documentation Structure

We've organized the documentation to help you quickly find what you need:

### Quick Start Guides (Fast, Essential)

1. **[DISTRIBUTION_QUICKSTART.md](DISTRIBUTION_QUICKSTART.md)**
   - One-page overview
   - Common commands
   - .app vs DMG comparison
   - Start here!

2. **[CODE_SIGNING_QUICKSTART.md](CODE_SIGNING_QUICKSTART.md)**
   - Get code signing set up in 5 minutes
   - Find your identity
   - Build signed apps
   - Essential for distribution

### Complete Guides (Detailed, Reference)

3. **[docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)**
   - Complete distribution guide
   - All options and workflows
   - Troubleshooting
   - Best practices

4. **[docs/CODE_SIGNING.md](docs/CODE_SIGNING.md)**
   - Comprehensive code signing guide
   - Getting certificates
   - Notarization process
   - CI/CD setup

5. **[scripts/README.md](scripts/README.md)**
   - All available build scripts
   - Script documentation
   - When to use each script

## Step-by-Step Workflows

### First Time Setup

```bash
# 1. Clone and navigate
git clone <repo>
cd Ferrufi

# 2. Verify linking works
./scripts/test_linking.sh

# 3. Build a test app
./scripts/build_app.sh 

# 4. Run it
open Ferrufi.app
```

### Development Build

```bash
# Quick build for testing
./scripts/build_app.sh 
```

### Beta Release

```bash
# 1. Set version
./scripts/set_version.sh 1.0.0-beta.1

# 2. Build unsigned for testers
./scripts/build_app.sh  --zip

# 3. Share the zip file
```

### Production Release (Unsigned)

```bash
# 1. Set version
./scripts/set_version.sh 1.0.0

# 2. Build and zip
./scripts/build_app.sh  --zip

# 3. Upload to GitHub/website
# Users will need to right-click → Open
```

### Production Release (Signed)

```bash
# 1. Set up code signing (one-time)
security find-identity -v -p codesigning
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM)"

# 2. Set version
./scripts/set_version.sh 1.0.0

# 3. Build signed app
./scripts/build_app.sh --zip

# 4. Distribute!
```

### Professional Release (Notarized)

```bash
# 1. Set up (one-time)
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM)"

# 2. Build and sign
./scripts/set_version.sh 1.0.0
./scripts/build_app.sh

# 3. Notarize
ditto -c -k --keepParent Ferrufi.app Ferrufi.zip
xcrun notarytool submit Ferrufi.zip \
  --apple-id "your@email.com" \
  --team-id "TEAM" \
  --password "app-password" \
  --wait

# 4. Staple
xcrun stapler staple Ferrufi.app

# 5. Create final zip
./scripts/build_app.sh --zip

# 6. Distribute!
```

## Common Scenarios

### "I just want to use it myself"

```bash
./scripts/build_app.sh 
cp -R Ferrufi.app /Applications/
```

### "I want to share with a few friends"

```bash
./scripts/build_app.sh  --zip
# Share Ferrufi-X.Y.Z-macos.zip
# Tell them: Right-click → Open (first time only)
```

### "I want to distribute publicly"

```bash
# Get Developer ID ($99/year)
# Then:
export CODESIGN_IDENTITY="Developer ID Application: Your Name"
./scripts/build_app.sh --zip
# Share Ferrufi-X.Y.Z-macos.zip
```

### "I want professional distribution"

```bash
# Same as above + notarization
# See: docs/CODE_SIGNING.md for full notarization guide
```

## Distribution Comparison

| Aspect | .app Bundle | DMG |
|--------|-------------|-----|
| **Build Time** | Fast (~5s) | Slower (~10-15s) |
| **File Size** | 3 MB (zipped) | 4-5 MB |
| **User Steps** | Unzip → Drag | Open → Drag → Eject |
| **Professional Look** | Standard | Customizable |
| **Recommended For** | Most uses | Official releases |
| **Build Script** | `build_app.sh` | `build_dmg_local.sh` |

## Code Signing Levels

| Level | What Users See | Cost | Command |
|-------|---------------|------|---------|
| None | ⚠️ "Unidentified developer" - must right-click | Free | `` |
| Ad-hoc | Only works on your Mac | Free | `CODESIGN_IDENTITY="-"` |
| Developer ID | ⚠️ Warning first launch only | $99/year | Set identity env var |
| Notarized | ✓ No warnings at all | $99/year | Developer ID + notarization |

## Troubleshooting

### Build Issues

```bash
# Test linking
./scripts/test_linking.sh

# Clean build
swift package clean
./scripts/build_app.sh 
```

### Code Signing Issues

```bash
# Check certificates
security find-identity -v -p codesigning

# Verify signature
codesign -v -v Ferrufi.app
spctl -a -v Ferrufi.app
```

### User Installation Issues

```bash
# Remove quarantine attribute
xattr -cr Ferrufi.app
```

## All Available Scripts

Located in `scripts/`:

- `build_app.sh` - Build standalone .app (recommended)
- `build_dmg_local.sh` - Build DMG installer
- `set_version.sh` - Update version number
- `test_linking.sh` - Verify libmufiz linking
- `copy_mufiz_dylib.sh` - Manual dylib copy (legacy)

## Documentation Map

```
Ferrufi/
├── DISTRIBUTION_QUICKSTART.md          ← Start here!
├── CODE_SIGNING_QUICKSTART.md          ← For distribution
├── COMPLETE_BUILD_GUIDE.md             ← You are here
├── docs/
│   ├── DISTRIBUTION.md                 ← Complete reference
│   ├── CODE_SIGNING.md                 ← Signing & notarization
│   ├── VERSIONING.md                   ← Version management
│   └── LIBMUFIZ_LINKING.md            ← Technical linking info
└── scripts/
    └── README.md                       ← All scripts documented
```

## Support

- Check the quickstart guides first
- Read the troubleshooting sections
- Run `./scripts/test_linking.sh` to diagnose issues
- File an issue on GitHub with error output

## Summary

**For development:** `./scripts/build_app.sh `

**For sharing:** `./scripts/build_app.sh  --zip`

**For distribution:** Get Developer ID + `./scripts/build_app.sh --zip`

**For professional releases:** Add notarization to the above

---

**Questions?** See the quick start guides or detailed documentation above.
