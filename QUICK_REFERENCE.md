# Ferrufi - Quick Reference Guide

**Version:** 0.0.0-exp.4.6eb4fb3  
**Status:** ✅ Ready for Testing  
**Last Updated:** January 11, 2025

---

## 🚀 Quick Start: Testing the Latest Build

### Download & Install

#### Method A — Installer script (recommended)
We provide a single-script installer (like Zed) that downloads the latest experimental build and installs Ferrufi to /Applications.

```bash
# Run the installer (recommended):
curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install.sh | sh

# Or download and run manually:
curl -L -o install.sh https://raw.githubusercontent.com/Mufi-Lang/Ferrufi/main/scripts/install.sh
sh install.sh --install-dir /Applications

# Useful flags:
#   --no-quarantine    Skip automatic xattr removal
#   --install-dir DIR  Install to a custom directory
#   --local FILE       Install from a local zip
#   --yes              Non-interactive (auto-accept prompts)
```

#### Method B — Manual download
If you prefer to install manually:

```bash
# 1. Visit the experimental release page and download the macOS zip:
#    https://github.com/Mufi-Lang/Ferrufi/releases/tag/experimental

# 2. Extract
unzip Ferrufi-<version>-macos.zip

# 3. Install to Applications
cp -R Ferrufi.app /Applications/

# 4. (Optional) Remove quarantine so users can open without Gatekeeper friction:
xattr -cr /Applications/Ferrufi.app

# 5. Launch
open /Applications/Ferrufi.app
```

### First Launch

- **Expected:** macOS Gatekeeper warning about unidentified developer
- **Action:** Right-click Ferrufi.app → Open → Click "Open"
- **Alternative:** System Settings → Privacy & Security → "Open Anyway"

---

## 🔨 Local Development

### Build from Source

```bash
# Build app bundle with zip
./scripts/build_app.sh --version dev-$(git rev-parse --short HEAD) --zip

# Test build
./scripts/test_linking.sh

# Set version
./scripts/set_version.sh 0.1.0
```

### Build Options

```bash
# Basic build (no zip)
./scripts/build_app.sh

# Build with custom version
./scripts/build_app.sh --version 1.0.0-beta1

# Build and create zip
./scripts/build_app.sh --zip

# Full custom build
./scripts/build_app.sh --version 2.0.0 --zip
```

### Install Local Build

```bash
# Copy to Applications
cp -R Ferrufi.app /Applications/

# Remove quarantine
xattr -cr /Applications/Ferrufi.app

# Verify entitlements
codesign -d --entitlements - /Applications/Ferrufi.app

# Verify signature
codesign -vv /Applications/Ferrufi.app

# Launch
open /Applications/Ferrufi.app
```

---

## 🧪 Testing Checklist

### File Operations (Critical)

- [ ] **Create Note:** Create a new note in a folder
- [ ] **Edit Note:** Modify note content and save
- [ ] **Delete Note:** Remove a note
- [ ] **Move Note:** Move note between folders
- [ ] **Rename Note:** Change note filename

### Configuration

- [ ] **Save Config:** Make changes and verify they persist
- [ ] **Load Config:** Restart app and verify settings loaded
- [ ] **Export Config:** Export configuration to file
- [ ] **Import Config:** Import configuration from file

### Shortcuts

- [ ] **Export Shortcuts:** Export keyboard shortcuts profile
- [ ] **Import Shortcuts:** Import shortcuts profile
- [ ] **Test Shortcuts:** Verify shortcuts work as expected

### Edge Cases

- [ ] **Large Files:** Create/edit notes with large content
- [ ] **Special Characters:** Use Unicode, emoji in filenames/content
- [ ] **Permissions:** Test without removing quarantine flag
- [ ] **Multiple Folders:** Work with many folders/notes

---

## 🔍 Verification Commands

### Check Entitlements

```bash
codesign -d --entitlements - /Applications/Ferrufi.app
```

**Should show:**
- `com.apple.security.app-sandbox = false`
- `com.apple.security.files.all = true`
- `com.apple.security.files.user-selected.read-write = true`
- `com.apple.security.cs.disable-library-validation = true`

### Check Signature

```bash
codesign -vv /Applications/Ferrufi.app
```

**Should show:**
- `valid on disk`
- `satisfies its Designated Requirement`

### Check Dylib

```bash
ls -lh /Applications/Ferrufi.app/Contents/Frameworks/libmufiz.dylib
otool -L /Applications/Ferrufi.app/Contents/MacOS/Ferrufi | grep libmufiz
```

**Should show:**
- Dylib exists in Frameworks folder
- `@rpath/libmufiz.dylib` in dependencies

### Check Architecture

```bash
lipo -info /Applications/Ferrufi.app/Contents/MacOS/Ferrufi
lipo -info /Applications/Ferrufi.app/Contents/Frameworks/libmufiz.dylib
```

**Currently:**
- Both are `arm64` only

### Remove Quarantine

```bash
xattr -l /Applications/Ferrufi.app
xattr -cr /Applications/Ferrufi.app
```

---

## 📦 Release Process

### Experimental Release (Automatic)

```bash
# Just push to main or develop
git push origin main

# CI will automatically:
# 1. Build the app
# 2. Create zip
# 3. Upload to "experimental" release
# 4. Version: {base}-exp.{run_number}.{commit_hash}
```

### Official Release (Manual)

```bash
# 1. Update version in Version.swift
# Edit: Sources/Ferrufi/Version.swift
# Set: major, minor, patch

# 2. Commit version bump
git add Sources/Ferrufi/Version.swift
git commit -m "Bump version to 1.0.0"

# 3. Create and push tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin main --tags

# 4. CI will automatically build and create release
```

### Check Release Status

```bash
# List recent workflow runs
gh run list --limit 5

# View latest run
gh run view

# View specific workflow
gh run list --workflow experimental-release.yml

# Download release
gh release download experimental
```

---

## 🐛 Common Issues

### Issue: "App is damaged and can't be opened"

```bash
# Fix: Remove quarantine
xattr -cr /Applications/Ferrufi.app
```

### Issue: "Library not loaded: @rpath/libmufiz.dylib"

```bash
# Verify dylib exists
ls -la /Applications/Ferrufi.app/Contents/Frameworks/libmufiz.dylib

# Check rpath
otool -l /Applications/Ferrufi.app/Contents/MacOS/Ferrufi | grep -A 2 LC_RPATH

# Should show: @executable_path/../Frameworks
```

### Issue: Permission denied when editing files

```bash
# Verify entitlements
codesign -d --entitlements - /Applications/Ferrufi.app

# Rebuild with latest version
git pull origin main
./scripts/build_app.sh --zip
```

### Issue: CI build failing

```bash
# Check workflow runs
gh run list --workflow experimental-release.yml

# View failure logs
gh run view --log-failed

# Common fixes:
# - Ensure Ferrufi.entitlements is committed
# - Ensure libmufiz.dylib is in Sources/CMufi/
# - Check Swift version in Package.swift
```

---

## 📊 Key Files & Locations

### Source Code

```
Sources/
├── Ferrufi/
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── Folder.swift          # File operations
│   │   │   └── Configuration.swift   # Config I/O
│   │   └── Storage/
│   │       ├── FileStorage.swift            # File management
│   │       └── SecurityScopedFileAccess.swift  # Security helper
│   ├── UI/
│   │   ├── Views/
│   │   │   └── ShortcutsSettingsView.swift
│   │   └── Shortcuts/
│   │       └── ShortcutsManager.swift
│   └── Version.swift                 # Version numbers
└── CMufi/
    └── libmufiz.dylib               # Native runtime

Ferrufi.entitlements                 # Security entitlements
Package.swift                        # Swift package config
```

### Build Scripts

```
scripts/
├── build_app.sh          # Main build script
├── build_dmg_local.sh    # DMG builder (optional)
├── test_linking.sh       # Link verification
└── set_version.sh        # Version updater
```

### CI/CD

```
.github/workflows/
├── experimental-release.yml   # Auto builds on push
├── macos-release.yml         # Official release on tag
└── README.md                 # Workflow docs
```

### Documentation

```
CURRENT_STATUS.md                    # Complete status (this doc's big brother)
QUICK_REFERENCE.md                   # This file
DISTRIBUTION_QUICKSTART.md           # Distribution guide
plans/FILE_ACCESS_FIX.md              # Technical details
SECURITY_SCOPED_RESOURCES_FIX.md     # Security scope guide
ENTITLEMENTS_FIX_SUMMARY.md          # Entitlements reference
```

---

## 💡 Pro Tips

### Faster Development

```bash
# Build and install in one command
./scripts/build_app.sh --version dev && \
  cp -R Ferrufi.app /Applications/ && \
  xattr -cr /Applications/Ferrufi.app && \
  open /Applications/Ferrufi.app

# Watch for changes (requires fswatch)
fswatch -o Sources/ | xargs -n1 -I{} ./scripts/build_app.sh
```

### Clean Builds

```bash
# Remove build artifacts
rm -rf .build/
rm -rf Ferrufi.app/
rm -f Ferrufi-*.zip

# Full clean rebuild
swift package clean
./scripts/build_app.sh --zip
```

### Testing on Fresh System

```bash
# Create new test user account
# System Settings → Users & Groups → Add User

# Switch to test user
# Test installation from scratch
# Verify Gatekeeper behavior
```

---

## 📈 Version Numbers

### Current Versions

- **Base Version:** 0.0.0 (in `Version.swift`)
- **Experimental:** 0.0.0-exp.4.6eb4fb3
- **Swift Tools:** 6.0 (in `Package.swift`)
- **macOS Target:** 14.0+ (Sonoma and later)

### Update Version

```bash
# Option 1: Use script
./scripts/set_version.sh 1.0.0

# Option 2: Manual edit
# Edit Sources/Ferrufi/Version.swift:
#   major = 1
#   minor = 0
#   patch = 0
```

---

## 🔗 Quick Links

- **Repository:** https://github.com/Mufi-Lang/Ferrufi
- **Experimental Release:** https://github.com/Mufi-Lang/Ferrufi/releases/tag/experimental
- **Latest Official:** https://github.com/Mufi-Lang/Ferrufi/releases/latest
- **Issues:** https://github.com/Mufi-Lang/Ferrufi/issues
- **Actions:** https://github.com/Mufi-Lang/Ferrufi/actions

---

## ✨ What's Working

✅ Security-scoped file access  
✅ Entitlements properly applied  
✅ Dylib bundled and loading  
✅ Ad-hoc code signing  
✅ CI/CD automated builds  
✅ Experimental releases  
✅ File editing in /Applications  
✅ All CRUD operations on notes  
✅ Configuration import/export  
✅ Shortcuts import/export  

---

## 🎯 TODO (Optional Future Work)

- [ ] Universal binary (arm64 + x86_64)
- [ ] Developer ID signing
- [ ] Notarization
- [ ] DMG installer with branding
- [ ] Sparkle auto-updates
- [ ] Homebrew cask
- [ ] Performance benchmarks
- [ ] UI automated tests

---

**Need Help?**

1. Check `CURRENT_STATUS.md` for detailed information
2. Review `plans/FILE_ACCESS_FIX.md` for technical details
3. Open an issue: https://github.com/Mufi-Lang/Ferrufi/issues
4. Check workflow runs: https://github.com/Mufi-Lang/Ferrufi/actions

---

**Everything is ready to test!** 🚀