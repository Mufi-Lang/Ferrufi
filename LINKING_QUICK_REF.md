# libmufiz Linking - Quick Reference Card

## ⚡ Quick Commands

```bash
# First time setup
swift build

# Clean rebuild
swift package clean && swift build

# Verify linking
./scripts/test_linking.sh

# Run app
swift run FerrufiApp

# Create DMG
./build_macos.sh
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `Sources/CMufi/libmufiz.dylib` | Mufi runtime library (arm64) |
| `Sources/CMufi/mufiz.h` | C API header |
| `Sources/CMufi/module.modulemap` | Swift module map |
| `scripts/copy_mufiz_dylib.sh` | Legacy helper (no longer needed) |
| `scripts/test_linking.sh` | Validate linking setup |
| `build_macos.sh` | Build and package DMG |

## 🔧 What Was Fixed

1. ✅ **build_macos.sh**: Path changed from `include/` → `Sources/CMufi/`
2. ✅ **Package.swift**: Added linker settings with automatic rpath configuration
3. ✅ **Automatic rpath**: Dylib found via `@loader_path/../../../Sources/CMufi`
4. ✅ **Test script**: Created `scripts/test_linking.sh`
5. ✅ **Documentation**: Added comprehensive guides
6. ✅ **No manual steps**: Build system handles dylib automatically

## 🐛 Troubleshooting

| Error | Fix |
|-------|-----|
| `library not found for -lmufiz` | Verify dylib exists, clean rebuild |
| `Library not loaded: @rpath/libmufiz.dylib` | Check rpath: `otool -l`, clean rebuild |
| `No such module 'CMufi'` | `swift package clean && swift build` |
| Architecture mismatch | Check: `lipo -info Sources/CMufi/libmufiz.dylib` |

## 🔍 Diagnostics

```bash
# Check dylib exists and architecture
ls -l Sources/CMufi/libmufiz.dylib
lipo -info Sources/CMufi/libmufiz.dylib

# Verify linking
otool -L .build/arm64-apple-macosx/debug/FerrufiApp | grep mufiz

# Check rpath
otool -l .build/arm64-apple-macosx/debug/FerrufiApp | grep -A2 LC_RPATH

# Full validation
./scripts/test_linking.sh
```

## 📚 Documentation

- **Comprehensive Guide**: `docs/LIBMUFIZ_LINKING.md`
- **Quick Start**: `docs/QUICK_START.md`
- **Changelog**: `docs/CHANGELOG_LINKING_FIX.md`
- **Scripts Guide**: `scripts/README.md`
- **Full Summary**: `LINKING_FIX_SUMMARY.md`

## ⚙️ How It Works

```
Build Time:
  Package.swift → linkerSettings: ["-L Sources/CMufi", "-lmufiz"]
  → Linker finds libmufiz.dylib in Sources/CMufi/
  
Runtime (Development):
  Package.swift → Sets rpath: @loader_path/../../../Sources/CMufi
  → App finds dylib automatically (no copying needed)
  
Runtime (Distribution):
  build_macos.sh → Bundles into Contents/Frameworks/
  → App finds dylib via @rpath (@executable_path/../Frameworks)
```

## ⚠️ Known Warning (Non-Critical)

```
ld: warning: building for macOS-14.0, but linking with dylib 
'@rpath/libmufiz.dylib' which was built for newer version 26.2
```

**Impact**: None (dylib works on macOS 14.0)  
**Future**: Rebuild dylib with correct deployment target

## 🎉 Automatic Dylib Handling

The build system now automatically handles `libmufiz.dylib`:
- ✅ No manual copying required
- ✅ Rpath configured automatically in Package.swift
- ✅ Works for debug, release, and test builds
- ✅ Just run `swift build` and go!

## ✅ Verification Checklist

- [ ] `Sources/CMufi/libmufiz.dylib` exists
- [ ] `swift build` completes without errors
- [ ] `./scripts/test_linking.sh` passes all tests
- [ ] `otool -L` shows `@rpath/libmufiz.dylib` is linked
- [ ] `otool -l` shows rpath includes `Sources/CMufi`
- [ ] App runs: `swift run FerrufiApp`

## 🎯 Current Status

✅ **COMPLETE** - All linking issues resolved  
🏗️ **Architecture**: arm64 (Apple Silicon)  
📦 **Swift**: 6.2+  
🍎 **macOS**: 14.0+

---

**Quick Help**: Run `./scripts/test_linking.sh` for automated diagnostics