# Ferrufi Quick Start Guide

## Building Ferrufi on macOS

### Prerequisites

- macOS 14.0 or later
- Swift 6.2 or later
- Xcode 15 or later (optional)

### Quick Build

```bash
# 1. Clone the repository
git clone <repository-url>
cd Ferrufi

# 2. Build the app (dylib is automatically handled)
swift build --product FerrufiApp

# 3. Run the app
swift run FerrufiApp
```

### Building a DMG for Distribution

```bash
./build_macos.sh
```

This creates `Ferrufi-<VERSION>-macos.dmg` in the current directory.

## Troubleshooting

### "Library not loaded: @rpath/libmufiz.dylib"

**Solution**: This should not occur with the automatic rpath configuration. If it does:
```bash
# Verify the dylib exists
ls -l Sources/CMufi/libmufiz.dylib

# Clean and rebuild
swift package clean
swift build
```

### "ld: library not found for -lmufiz"

**Solution**: Verify the library exists:
```bash
ls -l Sources/CMufi/libmufiz.dylib
```

If missing, you need to build or obtain `libmufiz.dylib` from the Mufi-lang repository.

The Package.swift is configured to automatically find the dylib at build time.

### Architecture Mismatch

Check the library architecture:
```bash
lipo -info Sources/CMufi/libmufiz.dylib
```

Current library is **arm64 only** (Apple Silicon). For Intel Macs, you'll need an x86_64 or universal binary.

## Development Workflow

### Run Tests

```bash
swift test
```

### Clean Build

```bash
swift package clean
swift build
```

### Debug Build

```bash
swift build  # Defaults to debug configuration
```

### Release Build

```bash
swift build -c release
```

### Using Xcode

```bash
# Generate Xcode project (if needed)
swift package generate-xcodeproj

# Open in Xcode
open Ferrufi.xcodeproj
```

**Note**: The dylib is automatically handled by the build system.

## Project Structure

```
Ferrufi/
├── Sources/
│   ├── CMufi/                  # Mufi runtime library (C interface)
│   │   ├── libmufiz.dylib      # Dynamic library (arm64)
│   │   ├── mufiz.h             # C API header
│   │   └── module.modulemap    # Swift module map
│   ├── Ferrufi/                # Core library
│   │   ├── Features/           # App features
│   │   ├── Integrations/       # External integrations (Mufi)
│   │   └── UI/                 # User interface components
│   └── FerrufiApp/             # Executable target
├── Tests/                      # Test suite
├── scripts/
│   ├── copy_mufiz_dylib.sh     # Helper script (legacy - not needed for builds)
│   └── test_linking.sh         # Validation script
├── docs/                       # Documentation
├── Package.swift               # Swift package manifest
└── build_macos.sh              # macOS build script
```

## Features

### Note Management
- Create, edit, and organize notes
- Rich text editing with Markdown support
- Tags and categories
- Search and filtering

### Mufi Integration
- Interactive Mufi REPL
- Execute Mufi code snippets
- Integrated runtime (libmufiz)

### UI
- Native SwiftUI interface
- Metal-accelerated rendering
- Dark mode support
- Customizable shortcuts

## Configuration

### Environment Variables

When building or running:

- `VERSION`: Set explicit version (optional)
- `CODESIGN_IDENTITY`: Code signing identity for distribution builds

**Note**: Library paths are automatically configured via Package.swift rpath settings.

### Package.swift

The package manifest defines:
- Minimum macOS version: 14.0
- Swift tools version: 6.2
- Targets: CMufi (system library), Ferrufi (library), FerrufiApp (executable)

## CI/CD

GitHub Actions workflow (`.github/workflows/macos-dmg-release.yml`):
- Automatically builds on push/PR
- Installs correct Swift toolchain
- Runs `build_macos.sh`
- Uploads DMG artifact

## Getting Help

### Documentation
- [Linking Guide](./LIBMUFIZ_LINKING.md) - Detailed linking documentation
- [Changelog](./CHANGELOG_LINKING_FIX.md) - Recent fixes and changes

### Debug Commands

```bash
# Check what libraries the binary links against
otool -L .build/arm64-apple-macosx/debug/FerrufiApp

# Check rpath settings
otool -l .build/arm64-apple-macosx/debug/FerrufiApp | grep -A3 LC_RPATH

# Verify dylib architecture
file Sources/CMufi/libmufiz.dylib

# Test dylib loading
DYLD_LIBRARY_PATH=Sources/CMufi .build/arm64-apple-macosx/debug/FerrufiApp
```

## Common Issues

### Swift Version Mismatch

**Error**: "Package.swift requires Swift tools version 6.2 but current is 6.1"

**Solution**: Update Swift toolchain:
- Install latest Xcode
- Or download Swift toolchain from [swift.org](https://swift.org/download/)

### Missing Dependencies

**Error**: "No such module 'CMufi'"

**Solution**: Clean and rebuild:
```bash
swift package clean
swift package resolve
swift build
```

### Xcode Project Generation Fails

**Error**: "swift package generate-xcodeproj failed"

**Solution**: This is non-fatal. Use SwiftPM directly:
```bash
swift build
# or
xcodebuild -scheme FerrufiApp -configuration Release
```

## Next Steps

1. ✅ Build the app successfully
2. 📖 Read the [full linking documentation](./LIBMUFIZ_LINKING.md)
3. 🧪 Run tests: `swift test`
4. ✅ Verify setup: `./scripts/test_linking.sh`
5. 🚀 Create a DMG: `./build_macos.sh`
6. 🎨 Explore the codebase
7. 🤝 Contribute improvements

## License

See LICENSE file in repository root.

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

---

**Questions?** Check the documentation in `docs/` or open an issue on GitHub.