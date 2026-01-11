# Ferrufi Distribution Quick Start

## TL;DR

**Most users should use this:**

```bash
./scripts/build_app.sh  --zip
```

This creates `Ferrufi.app` and `Ferrufi-X.Y.Z-macos.zip` that you can share directly.

**For signed builds:** See [Code Signing Quick Start](CODE_SIGNING_QUICKSTART.md) or jump to [Code Signing](#code-signing) below.

---

## What's the Difference?

### ✅ `.app` Bundle (Recommended)
- **File**: `Ferrufi.app` or `Ferrufi-X.Y.Z-macos.zip`
- **Size**: ~3 MB (compressed)
- **Best for**: Quick sharing, cloud storage, direct downloads
- **User steps**: Download → Unzip → Drag to Applications
- **Build**: `./scripts/build_app.sh --zip`

### 📦 `.dmg` Image (Optional)
- **File**: `Ferrufi-X.Y.Z-macos.dmg`
- **Size**: ~4-5 MB
- **Best for**: Professional releases, branded installers
- **User steps**: Download → Open → Drag to Applications → Eject
- **Build**: `./scripts/build_dmg_local.sh`

---

## Common Commands

```bash
# Quick build for testing (no signing)
./scripts/build_app.sh 

# Build with zip for distribution
./scripts/build_app.sh  --zip

# Build to Desktop
./scripts/build_app.sh  --zip --output ~/Desktop

# Build with specific version
./scripts/build_app.sh --version 1.0.0 --zip

# Build DMG instead
./scripts/build_dmg_local.sh 
```

---

## Complete Release Workflow

```bash
# 1. Set version
./scripts/set_version.sh 1.0.0

# 2. Build distributable
./scripts/build_app.sh  --zip

# 3. Share the zip file
# Upload Ferrufi-1.0.0-macos.zip to GitHub Releases, 
# Google Drive, Dropbox, or your website
```

---

## For Production (Code Signed)

```bash
# Set your Developer ID
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Build signed app
./scripts/build_app.sh --zip

# Or signed DMG
./scripts/build_dmg_local.sh
```

**How to get code signing identity:** See [Code Signing](#code-signing) section below or [CODE_SIGNING_QUICKSTART.md](CODE_SIGNING_QUICKSTART.md).

---

## What Gets Created?

### With `.app` bundle:
```
Ferrufi.app/                    # Ready-to-use application
  Contents/
    MacOS/Ferrufi              # Executable
    Frameworks/libmufiz.dylib  # Runtime library
    Info.plist                 # App metadata
```

### With `--zip` flag:
```
Ferrufi-X.Y.Z-macos.zip        # Compressed archive for sharing
```

---

## Installation for Users

### From .zip (Simple):
1. Download `Ferrufi-X.Y.Z-macos.zip`
2. Double-click to extract
3. Drag `Ferrufi.app` to Applications
4. Right-click → Open (first time only, if unsigned)

### From .dmg (Traditional):
1. Download `Ferrufi-X.Y.Z-macos.dmg`
2. Double-click to mount
3. Drag Ferrufi to Applications folder
4. Eject DMG
5. Right-click → Open (first time only, if unsigned)

---

## Troubleshooting

**"App is damaged"**
```bash
xattr -cr /Applications/Ferrufi.app
```

**Library not found**
```bash
# Rebuild with official script
./scripts/build_app.sh 
```

**Need help?**
```bash
./scripts/build_app.sh --help
./scripts/test_linking.sh
```

---

## Code Signing

### Quick Setup

```bash
# 1. Find your identity
security find-identity -v -p codesigning

# 2. Copy the identity name in quotes, e.g.:
#    "Developer ID Application: Your Name (TEAM123)"

# 3. Set it
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAM123)"

# 4. Build signed app
./scripts/build_app.sh --zip
```

### Get a Developer ID

**Need a certificate?**
- **Paid ($99/year):** Join Apple Developer Program at https://developer.apple.com/programs/
- **Free (local only):** Use ad-hoc signing: `export CODESIGN_IDENTITY="-"`

**Full guide:** [CODE_SIGNING_QUICKSTART.md](CODE_SIGNING_QUICKSTART.md)

### Why Sign?

| Type | Users Experience | Command |
|------|-----------------|---------|
| Unsigned | ⚠️ Must right-click → Open | `` |
| Signed | ✓ Warning first time only | With `CODESIGN_IDENTITY` |
| Notarized | ✓ No warnings | Signed + notarization |

---

## More Info

- **Code Signing:** [CODE_SIGNING_QUICKSTART.md](CODE_SIGNING_QUICKSTART.md) or [docs/CODE_SIGNING.md](docs/CODE_SIGNING.md)
- **Distribution:** [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md)
- **All Scripts:** [scripts/README.md](scripts/README.md)
- **Versioning:** [docs/VERSIONING.md](docs/VERSIONING.md)

---

**Default recommendation:** Use `./scripts/build_app.sh --zip` for 99% of use cases. Only use DMG if you need a professional installer experience.