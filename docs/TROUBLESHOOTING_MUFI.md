# Troubleshooting Mufi Runtime Issues

## Common Issue: Crash with "attempt to use null value"

### Symptoms

When running the app, you see a crash like this:

```
Mufi runtime initialized successfully
thread 287253 panic: attempt to use null value
???:?:?: 0x101a03a4b in _compiler.currentChunk (???)
???:?:?: 0x1019f9313 in _compiler.emitByte (???)
???:?:?: 0x1019f7b6b in _compiler.emitBytes (???)
???:?:?: 0x101a05843 in _compiler.emitConstant (???)
???:?:?: 0x101a10377 in _compiler.string (???)
```

### Root Cause

**This is a bug in `libmufiz.dylib` itself, NOT in the Ferrufi Swift code.**

The crash occurs inside the Mufi compiler when it tries to access a null `currentChunk` pointer. This means the Mufi runtime's internal compiler state was not properly initialized by `mufiz_init()`, or there's a bug in the compiler's string literal handling.

### Why This Happens

1. **Outdated Runtime**: The `libmufiz.dylib` file may be from an older version of Mufi-lang with known bugs
2. **Corrupted Build**: The dylib might have been compiled incorrectly
3. **Architecture Mismatch**: The dylib might not be properly compiled for your system
4. **Missing Dependencies**: The Mufi runtime might depend on other libraries

### Solutions

#### Solution 1: Rebuild libmufiz.dylib (Recommended)

You need to rebuild the Mufi runtime from the latest Mufi-lang source code:

```bash
# Clone the Mufi-lang repository
git clone https://github.com/your-org/mufi-lang
cd mufi-lang

# Build the runtime for macOS with correct deployment target
zig build -Drelease-safe -Dtarget=aarch64-macos.14

# Copy the built dylib to Ferrufi
cp zig-out/lib/libmufiz.dylib /path/to/Ferrufi/include/
```

**Important**: Ensure the build targets macOS 14.0 or later to match Ferrufi's deployment target.

#### Solution 2: Get Pre-built Runtime

If a pre-built `libmufiz.dylib` is available:

```bash
# Download the latest stable release
curl -O https://releases.mufi-lang.org/latest/libmufiz-macos-arm64.dylib

# Copy to Ferrufi
cp libmufiz-macos-arm64.dylib /path/to/Ferrufi/include/libmufiz.dylib

# Fix deployment target
cd /path/to/Ferrufi
./scripts/fix_mufiz_deployment_target.sh
```

#### Solution 3: Disable REPL Features Temporarily

If you need to use Ferrufi without the Mufi REPL while waiting for a fixed runtime:

1. Comment out the runtime initialization in `Sources/FerrufiApp/main.swift`:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    // TEMPORARILY DISABLED: Mufi runtime initialization
    /*
    Task {
        do {
            try await MufiBridge.shared.initialize(...)
            print("✓ Mufi runtime initialized successfully")
        } catch {
            print("✗ Failed to initialize Mufi runtime: \(error)")
        }
    }
    */
}
```

2. The editor will still work, but REPL features will be unavailable.

### Verification

After rebuilding or replacing `libmufiz.dylib`, verify it works:

```bash
# Check the dylib is valid
file include/libmufiz.dylib
# Should show: Mach-O 64-bit dynamically linked shared library arm64

# Check deployment target
otool -l include/libmufiz.dylib | grep -A 3 "LC_BUILD_VERSION"
# Should show: minos 14.0 (not 26.2)

# Run Ferrufi
swift run FerrufiApp
# Should start without crashes
```

### Testing the Fixed Runtime

Once you have a working `libmufiz.dylib`:

1. Launch Ferrufi
2. Create a new note
3. Click the terminal button (🖥️) to open the REPL
4. Type: `print("Hello from Mufi!")`
5. Press Enter

You should see:
```
> print("Hello from Mufi!")
Hello from Mufi!
```

### Understanding the Error

The stack trace shows:

```
compiler.currentChunk → emitByte → emitBytes → emitConstant → string
```

This is the Mufi compiler trying to:
1. Parse a string literal (`"Hello"`)
2. Emit it as a constant to the bytecode chunk
3. Access the current chunk pointer
4. **CRASH**: The chunk pointer is NULL

This means `mufiz_init()` didn't properly set up the compiler's internal state, or the state got corrupted.

### Known Working Configuration

A properly built `libmufiz.dylib` should:
- Be compiled with Zig 0.12+ (or whatever version Mufi-lang requires)
- Target `aarch64-macos.14` (for Apple Silicon) or `x86_64-macos.14` (for Intel)
- Have the deployment target set to 14.0
- Include all standard library functions (should print "Standard library initialized with 115 functions")
- Pass the health check with simple expressions like `1 + 1` or `print("test")`

### Getting Help

If you continue to experience issues:

1. **Check Mufi-lang version**: Ensure you're using the latest stable release
2. **Verify Zig version**: Make sure your Zig compiler version matches Mufi-lang's requirements
3. **Check architecture**: Confirm you're building for the correct CPU architecture
4. **Review build logs**: Look for warnings or errors during the dylib compilation
5. **Contact Mufi-lang maintainers**: Report the issue to the Mufi-lang project

### Workaround: External Process Mode

As a last resort, you can use the process-based REPL that spawns an external `mufiz` binary:

1. Install the `mufiz` command-line tool separately
2. Use `MufiRunner` instead of `MufiBridge`
3. This avoids the embedded runtime but requires the external binary

See `Sources/Ferrufi/Features/Mufi/MufiRunner.swift` for the process-based implementation.

---

## Other Common Issues

### Runtime Doesn't Initialize

**Error**: `Failed to initialize Mufi runtime: initializationFailed(code: -1)`

**Solution**: 
- The runtime returned a failure code
- Check that `mufiz_init()` is implemented correctly in the dylib
- Ensure the dylib is compatible with your system

### Runtime Not Found

**Error**: `dyld: Library not loaded: @rpath/libmufiz.dylib`

**Solution**:
```bash
# Copy the dylib to build output
./scripts/copy_mufiz_dylib.sh

# Rebuild
swift build
```

### Memory Leaks Warning

**Warning**: Mufi runtime reports memory leaks on shutdown

**Solution**:
- This is usually harmless for short-running sessions
- Enable leak detection to diagnose: `enableLeakDetection: true`
- Call `await MufiBridge.shared.deinitialize()` before app quit

### REPL Hangs

**Issue**: REPL stops responding after some commands

**Solution**:
- The runtime might have crashed silently
- Restart the app
- Avoid infinite loops in Mufi code
- Check for recursion depth issues

---

## Debug Mode

To enable more verbose logging:

```swift
// In MufiBridge.swift, add print statements:

public func interpret(_ source: String) async throws -> (UInt8, String) {
    print("DEBUG: Interpreting: \(source)")
    guard initialized else {
        print("DEBUG: Runtime not initialized!")
        throw MufiError.notInitialized
    }
    
    // ... rest of function
    print("DEBUG: Interpretation complete, status: \(status)")
}
```

This will help identify where the crash occurs.

---

## Summary

The "attempt to use null value" crash is **always** a bug in `libmufiz.dylib`, not in Ferrufi's Swift code. The solution is to rebuild or replace the dylib with a properly working version from the Mufi-lang project.

Until the dylib is fixed, you can:
1. Comment out runtime initialization
2. Use the process-based REPL as a workaround
3. Use Ferrufi for regular note-taking without Mufi features

For the latest updates on this issue, check:
- Mufi-lang GitHub Issues
- Ferrufi GitHub Discussions
- The `#mufi-runtime` channel in the community Discord