# Automatic libmufiz.dylib Handling - Complete Guide

## 🎉 What Changed

The Ferrufi build system now **automatically handles** the `libmufiz.dylib` runtime library. No manual copying or helper scripts required!

### Before (Manual Process)

```bash
# Old workflow - required manual steps
git clone <repo>
cd Ferrufi
./scripts/copy_mufiz_dylib.sh  # ❌ Manual step required
swift build
./scripts/copy_mufiz_dylib.sh  # ❌ Required after every clean
swift test
```

### After (Automatic)

```bash
# New workflow - just build and go!
git clone <repo>
cd Ferrufi
swift build                     # ✅ Dylib automatically handled
swift test                      # ✅ Works without manual steps
swift run FerrufiApp           # ✅ Just works!
```

## 🔧 How It Works

### Technical Implementation

The build system uses **rpath** (runtime path) configuration to automatically locate the dylib at runtime:

1. **Package.swift Configuration**
   ```swift
   .executableTarget(
       name: "FerrufiApp",
       dependencies: ["Ferrufi"],
       linkerSettings: [
           .unsafeFlags(["-L", "Sources/CMufi"]),
           .unsafeFlags([
               "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../Sources/CMufi",
               "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../Sources/CMufi",
           ]),
           .linkedLibrary("mufiz"),
       ]
   )
   ```

2. **Build Time**: The linker finds `libmufiz.dylib` using `-L Sources/CMufi`

3. **Runtime**: The dynamic linker finds the dylib using rpath:
   - `@loader_path/../../../Sources/CMufi` - relative to the loader location
   - `@executable_path/../../../Sources/CMufi` - relative to the executable

### Rpath Explained

From the build output directory (e.g., `.build/arm64-apple-macosx/debug/`), the rpath points:
```
.build/arm64-apple-macosx/debug/FerrufiApp
                          ↓ (go up 3 levels)
.build/arm64-apple-macosx/
       ↓
.build/
       ↓
<project root>/
       ↓
Sources/CMufi/libmufiz.dylib  ✅ Found!
```

## ✅ Benefits

1. **Simplified Workflow**: No manual scripts to run
2. **Automatic**: Works for all build types (debug, release, test)
3. **Reliable**: No risk of forgetting to copy the dylib
4. **Clean Builds**: `swift package clean` just works
5. **New Developers**: Onboarding is simpler - just `swift build`
6. **CI/CD**: No additional steps needed in workflows

## 🚀 Usage

### Build

```bash
swift build --product FerrufiApp
# Dylib is automatically found via rpath
```

### Run

```bash
swift run FerrufiApp
# No DYLD_LIBRARY_PATH or manual setup needed
```

### Test

```bash
swift test
# Tests automatically use the configured rpath
```

### Clean Rebuild

```bash
swift package clean
swift build
# No helper script needed!
```

### Create DMG

```bash
./build_macos.sh
# Script automatically bundles dylib into app package
```

## 🔍 Verification

### Check Linked Libraries

```bash
otool -L .build/arm64-apple-macosx/debug/FerrufiApp | grep mufiz
```

Expected output:
```
@rpath/libmufiz.dylib (compatibility version 1.0.0, current version 1.0.0)
```

### Check Rpath Configuration

```bash
otool -l .build/arm64-apple-macosx/debug/FerrufiApp | grep -A2 "LC_RPATH" | grep "Sources/CMufi"
```

Expected output:
```
         path @loader_path/../../../Sources/CMufi (offset 12)
         path @executable_path/../../../Sources/CMufi (offset 12)
```

### Verify Dylib is Reachable

```bash
cd .build/arm64-apple-macosx/debug
ls -la ../../../Sources/CMufi/libmufiz.dylib
```

Expected: File exists and is readable

### Run Automated Tests

```bash
./scripts/test_linking.sh
```

Expected: All tests pass with "🎉 Automatic dylib handling is working!"

## 📋 Migration Guide

### For Existing Developers

If you have an existing clone of the repository:

```bash
# 1. Pull the latest changes
git pull

# 2. Clean any old build artifacts
swift package clean

# 3. Build normally - dylib is now automatic!
swift build

# 4. Verify (optional)
./scripts/test_linking.sh
```

**You no longer need to run `./scripts/copy_mufiz_dylib.sh`!**

### For New Developers

```bash
# 1. Clone and build
git clone <repository-url>
cd Ferrufi
swift build

# That's it! No manual steps required.
```

## 🐛 Troubleshooting

### Error: "Library not loaded: @rpath/libmufiz.dylib"

This should not occur with automatic rpath configuration. If it does:

1. **Verify dylib exists**:
   ```bash
   ls -l Sources/CMufi/libmufiz.dylib
   ```

2. **Check rpath configuration**:
   ```bash
   otool -l .build/*/debug/FerrufiApp | grep -A2 LC_RPATH
   ```
   Should show paths to `Sources/CMufi`

3. **Clean rebuild**:
   ```bash
   swift package clean
   swift build
   ```

4. **Verify Package.swift**:
   Check that executable targets have rpath linker settings

### Error: "ld: library not found for -lmufiz"

This is a build-time error. Solutions:

1. **Verify dylib exists**:
   ```bash
   ls -l Sources/CMufi/libmufiz.dylib
   ```

2. **Check architecture**:
   ```bash
   lipo -info Sources/CMufi/libmufiz.dylib
   file Sources/CMufi/libmufiz.dylib
   ```
   Should match your Mac's architecture (arm64 for Apple Silicon, x86_64 for Intel)

3. **Verify Package.swift has linker settings**:
   ```swift
   linkerSettings: [
       .unsafeFlags(["-L", "Sources/CMufi"]),
       .linkedLibrary("mufiz"),
   ]
   ```

### Warning: "duplicate -rpath ... ignored"

This warning appears if multiple targets set the same rpath. It's non-critical but can be fixed by:

- Only setting rpath on executable targets (not library targets)
- The current Package.swift is already optimized to avoid this

## 📚 Technical Details

### Targets Configuration

| Target | Linker Settings |
|--------|----------------|
| `CMufi` | System library (no settings needed) |
| `Ferrufi` | `-L Sources/CMufi`, `-lmufiz` (library search only) |
| `FerrufiApp` | Library search + rpath configuration |
| `FerrufiTests` | Library search + rpath configuration |

### Why Rpath on Executables Only?

- **Library targets** don't need rpath (they're not executed directly)
- **Executable targets** need rpath to find dylibs at runtime
- This avoids duplicate rpath warnings during linking

### Distribution Builds

For DMG/app bundles, `build_macos.sh`:

1. Builds the app with SwiftPM or Xcode
2. Copies `libmufiz.dylib` to `Contents/Frameworks/`
3. Sets dylib install name: `@rpath/libmufiz.dylib`
4. Adds app rpath: `@executable_path/../Frameworks`
5. Creates self-contained DMG

## 🎯 Summary

### What You Need to Know

✅ **No manual copying required** - Build system handles everything  
✅ **Works for all build types** - Debug, release, and tests  
✅ **Automatic rpath configuration** - Package.swift sets it up  
✅ **Clean builds just work** - No helper scripts needed  
✅ **Simpler onboarding** - New developers just `swift build`  

### What's Deprecated

❌ **`./scripts/copy_mufiz_dylib.sh`** - No longer needed for builds  
❌ **Manual DYLD_LIBRARY_PATH setup** - Automatic via rpath  
❌ **Post-clean manual steps** - Everything is automatic  

### Legacy Script

The `scripts/copy_mufiz_dylib.sh` script is kept for:
- Reference and documentation
- Special edge cases (if any)
- Backward compatibility

But **you don't need to use it** for normal development!

## 🔗 Related Documentation

- **Quick Start**: `docs/QUICK_START.md` - Getting started guide
- **Linking Guide**: `docs/LIBMUFIZ_LINKING.md` - Comprehensive linking documentation
- **Quick Reference**: `LINKING_QUICK_REF.md` - Command cheat sheet
- **Full Summary**: `LINKING_FIX_SUMMARY.md` - Complete fix documentation
- **Scripts Guide**: `scripts/README.md` - Helper scripts documentation

## 📝 Changelog

### v2.0 - Automatic Dylib Handling

- ✅ Added automatic rpath configuration to Package.swift
- ✅ Eliminated need for manual `copy_mufiz_dylib.sh` execution
- ✅ Simplified developer workflow
- ✅ Updated all documentation
- ✅ Enhanced test_linking.sh validation script
- ✅ Maintained full backward compatibility

### v1.0 - Initial Linking Fix

- Fixed incorrect library paths in build_macos.sh
- Created copy_mufiz_dylib.sh helper script
- Added linker settings to Package.swift
- Comprehensive documentation

---

**Status**: ✅ Fully Implemented and Tested  
**Version**: 2.0  
**Date**: 2024  
**Platform**: macOS 14+ / Swift 6.2+ / Apple Silicon (arm64)  
**Developer Experience**: ⭐⭐⭐⭐⭐ Just works!  

**Questions?** Run `./scripts/test_linking.sh` to verify your setup!