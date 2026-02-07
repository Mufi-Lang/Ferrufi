# libmufiz Linking Guide

## Overview

Ferrufi uses the Mufi language runtime library (`libmufiz.dylib`) through a system library module called `CMufi`. This document explains how the linking is configured and how to troubleshoot linking issues.

## Architecture

### File Structure

```
Ferrufi/
├── Sources/
│   └── CMufi/                      # System library module for Mufi
│       ├── libmufiz.dylib          # The Mufi runtime dynamic library
│       ├── mufiz.h                 # C API header
│       └── module.modulemap        # Swift module map
├── scripts/
│   └── copy_mufiz_dylib.sh         # Helper script to copy dylib to build dirs
└── build_macos.sh                  # macOS build and packaging script
```

### How It Works

1. **System Library Module (`CMufi`)**
   - Defined in `Package.swift` as a `.systemLibrary()` target
   - Points to `Sources/CMufi` directory
   - Contains the C header, module map, and dynamic library

2. **Module Map (`module.modulemap`)**
   ```
   module CMufi [system] {
       header "mufiz.h"
       export *
       link "mufiz"
   }
   ```
   - Declares the module as a system module
   - Links against `libmufiz` (the linker looks for `libmufiz.dylib`)

3. **Linker Settings in `Package.swift`**
   - Both `Ferrufi` and `FerrufiApp` targets specify:
     - `-L Sources/CMufi` flag to add library search path
     - `.linkedLibrary("mufiz")` to link the library

4. **Runtime Library Search**
   - Package.swift configures rpaths automatically: `@loader_path/../../../Sources/CMufi` and `@executable_path/../../../Sources/CMufi`
   - No manual copying needed - the dylib is found via rpath at runtime
   - Build script sets `LIBRARY_PATH` for build-time linking
   - Final app bundles include the dylib in `Contents/Frameworks/`

## Building Locally

### Prerequisites

- macOS 14.0 or later
- Swift 6.2 or later
- Xcode 15 or later (optional, for Xcode builds)

### Build Steps

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd Ferrufi
   ```

2. **Verify libmufiz.dylib exists:**
   ```bash
   ls -l Sources/CMufi/libmufiz.dylib
   file Sources/CMufi/libmufiz.dylib
   ```

3. **Build with Swift Package Manager:**
   ```bash
   swift build --product FerrufiApp
   ```
   
   The build system automatically configures rpaths to find the dylib.

4. **Run the app:**
   ```bash
   swift run FerrufiApp
   ```

### Building a DMG (macOS only)

```bash
./build_macos.sh
```

This will:
- Build the app (using Xcode project or SwiftPM)
- Automatically locate the dylib via configured library paths
- Bundle `libmufiz.dylib` into the app's Frameworks folder
- Fix rpath references for the bundled app
- Create a `.dmg` file for distribution

## Troubleshooting

### Error: "Library not loaded: @rpath/libmufiz.dylib"

**Cause:** The dylib is not in the runtime library search path (should not occur with automatic rpath configuration).

**Solution:**
1. Verify the dylib exists: `ls -l Sources/CMufi/libmufiz.dylib`
2. Check rpath settings: `otool -l .build/*/debug/FerrufiApp | grep LC_RPATH`
3. Verify rpath includes `@loader_path/../../../Sources/CMufi`
4. Clean and rebuild: `swift package clean && swift build`

### Error: "ld: library not found for -lmufiz"

**Cause:** The linker cannot find the dylib during the link phase.

**Solution:**
1. Ensure `Sources/CMufi/libmufiz.dylib` exists
2. Check that `Package.swift` has the correct linker settings (executable targets):
   ```swift
   linkerSettings: [
       .unsafeFlags(["-L", "Sources/CMufi"]),
       .unsafeFlags([
           "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../Sources/CMufi",
           "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../Sources/CMufi",
       ]),
       .linkedLibrary("mufiz"),
   ]
   ```
3. The rpath is automatically set during build - no manual environment variables needed

### Error: "No such module 'CMufi'"

**Cause:** The system library module is not being recognized.

**Solution:**
1. Verify `Sources/CMufi/module.modulemap` exists and is valid
2. Check that `Package.swift` declares the CMufi target:
   ```swift
   .systemLibrary(
       name: "CMufi",
       path: "Sources/CMufi"
   )
   ```
3. Clean and rebuild: `swift package clean && swift build`

### Warning: "building for macOS-14.0, but linking with dylib built for newer version"

**Cause:** The `libmufiz.dylib` was built with a newer SDK version than the deployment target.

**Impact:** Usually non-critical; the dylib will work on the target OS if it doesn't use newer APIs.

**Solution (if needed):**
1. Rebuild `libmufiz.dylib` with the correct deployment target
2. Or update the deployment target in `Package.swift`:
   ```swift
   platforms: [
       .macOS(.v14)  // Or higher version
   ]
   ```

### Architecture Mismatch (Intel vs Apple Silicon)

**Check dylib architecture:**
```bash
lipo -info Sources/CMufi/libmufiz.dylib
```

**For universal binary (both architectures):**
The dylib should be rebuilt as a universal binary:
```bash
# If you have both x86_64 and arm64 versions:
lipo -create libmufiz_x86_64.dylib libmufiz_arm64.dylib -output libmufiz.dylib
```

## CI/CD (GitHub Actions)

The `.github/workflows/macos-dmg-release.yml` workflow:

1. Sets up the correct Swift toolchain based on `Package.swift`
2. Runs `build_macos.sh` which:
   - Sets library search paths
   - Builds the app
   - Runs `copy_mufiz_dylib.sh`
   - Bundles the dylib into the app
   - Creates a DMG
3. Uploads the DMG as an artifact

### Key Environment Variables

- `VERSION`: Build version string
- `CODESIGN_IDENTITY`: Code signing identity (optional)
- `LIBRARY_PATH`: Library search path (set by build script for build-time linking)

**Note**: Runtime library paths are automatically configured via rpath settings in Package.swift.

## Development Tips

### Running Tests with libmufiz

```bash
# Tests automatically use the configured rpath
swift test
```

### Using in Xcode

If you generate an Xcode project:

```bash
swift package generate-xcodeproj
open Ferrufi.xcodeproj
```

The Xcode project will inherit the linker settings from `Package.swift`.

### Debugging Linking Issues

**Check what libraries the binary links against:**
```bash
otool -L .build/arm64-apple-macosx/debug/FerrufiApp
```

**Check rpath settings:**
```bash
otool -l .build/arm64-apple-macosx/debug/FerrufiApp | grep -A3 LC_RPATH
```

**Verify dylib dependencies:**
```bash
otool -L Sources/CMufi/libmufiz.dylib
```

**Test if the dylib loads:**
```bash
# Should work automatically via rpath
.build/arm64-apple-macosx/debug/FerrufiApp

# Or verify the dylib path is reachable from the executable
cd .build/arm64-apple-macosx/debug
ls -la ../../../Sources/CMufi/libmufiz.dylib
```

## Updating libmufiz.dylib

When updating the Mufi runtime library:

1. Build the new `libmufiz.dylib` from the Mufi-lang repository
2. Replace `Sources/CMufi/libmufiz.dylib`
3. Update `Sources/CMufi/mufiz.h` if the API changed
4. Rebuild: `swift build` (dylib is automatically found via rpath)
5. Test: `swift test`

## References

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [System Library Targets](https://github.com/apple/swift-package-manager/blob/main/Documentation/Usage.md#system-library-targets)
- [macOS Dynamic Library Programming](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/DynamicLibraries/)
- [Mufi Language Repository](https://github.com/Mustafif/Mufi-lang)