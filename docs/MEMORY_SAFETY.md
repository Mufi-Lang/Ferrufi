# Memory Safety in Mufi REPL Integration

## Overview

The Mufi REPL integration in Ferrufi uses careful memory management to prevent crashes, leaks, and segmentation faults when interfacing between Swift and the C-based Mufi runtime.

## Key Safety Measures

### 1. String Memory Management

**Problem**: Passing Swift strings to C functions requires careful handling to prevent use-after-free or null pointer issues.

**Solution**:
```swift
// Use withCString to ensure the string remains valid during C call
trimmedSource.withCString { (cString: UnsafePointer<CChar>) -> UInt8 in
    return mufiz_interpret(cString)
}
```

**Why this works**:
- `withCString` ensures the C string pointer is valid for the closure's duration
- Swift manages the memory and automatically null-terminates the string
- The pointer is guaranteed to remain valid until the closure returns

### 2. Descriptor Management

**Problem**: File descriptor leaks can cause the process to run out of file handles.

**Solution**:
```swift
// Create pipe
var fds: [Int32] = [0, 0]
guard pipe(&fds) == 0 else { return (body(), "") }
let readFD = fds[0]
let writeFD = fds[1]

// ... use descriptors ...

// Explicitly close in the correct order
close(writeFD)
// ... after use ...
close(readFD)
```

**Why this works**:
- Each descriptor is closed exactly once
- Cleanup happens in reverse order of allocation
- Early returns include cleanup code

### 3. Memory Buffer Allocation

**Problem**: Reading output from the pipe requires a buffer that must be properly deallocated.

**Solution**:
```swift
let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
defer { buffer.deallocate() }
```

**Why this works**:
- `defer` ensures deallocation happens even if early return or error
- Buffer lifetime is clearly scoped
- No possibility of memory leak

### 4. Actor Isolation

**Problem**: Concurrent calls to the Mufi runtime can cause state corruption.

**Solution**:
```swift
public actor MufiBridge {
    public func interpret(_ source: String) async throws -> (UInt8, String) {
        // Actor ensures only one call at a time
    }
}
```

**Why this works**:
- Swift actors serialize access automatically
- No manual locking required
- Thread-safe by design

### 5. Autoreleasepool

**Problem**: Repeated REPL calls can build up autorelease objects, increasing memory usage.

**Solution**:
```swift
return await Task.detached(priority: .userInitiated) { [trimmedSource] in
    return autoreleasepool {
        // Run interpretation here
    }
}
```

**Why this works**:
- Each interpretation gets its own autorelease pool
- Temporary objects are freed immediately after each call
- Memory usage stays bounded

### 6. Input Validation

**Problem**: Invalid input can crash the C runtime.

**Solution**:
```swift
// Validate source code
guard !trimmedSource.isEmpty else { return (0, "") }
guard !trimmedSource.contains("\0") else { throw ... }
guard trimmedSource.utf8.count < 10_000_000 else { throw ... }
guard trimmedSource.canBeConverted(to: .utf8) else { throw ... }
```

**Why this works**:
- Null bytes would terminate C strings prematurely
- Size limits prevent memory exhaustion
- UTF-8 validation prevents encoding issues

### 7. Timeout Protection

**Problem**: Infinite loops or long computations can hang the REPL.

**Solution**:
```swift
let result = try await withThrowingTaskGroup(of: (UInt8, String).self) { group in
    group.addTask {
        try await MufiBridge.shared.interpret(trimmedSource)
    }
    group.addTask {
        try await Task.sleep(nanoseconds: 30_000_000_000) // 30s timeout
        throw MufiError.captureFailed(reason: "Interpretation timeout")
    }
    let result = try await group.next()!
    group.cancelAll()
    return result
}
```

**Why this works**:
- Timeout task races against interpretation
- First to complete wins
- Prevents indefinite hangs

### 8. State Validation

**Problem**: Using the runtime after deinitialization causes crashes.

**Solution**:
```swift
public func interpret(_ source: String) async throws -> (UInt8, String) {
    guard initialized else {
        throw MufiError.notInitialized
    }
    // ... rest of function
}
```

**Why this works**:
- Check happens before any C calls
- Provides clear error message
- Prevents segfaults from calling deinitialized runtime

### 9. C String Memory Management

**Problem**: Strings returned from C need proper ownership tracking.

**Solution**:
```swift
public func strdupToSwift(_ src: String) -> String? {
    return src.withCString { (ptr: UnsafePointer<CChar>) -> String? in
        guard let cCopy = mufiz_strdup(ptr) else { return nil }
        let swiftString = String(cString: cCopy)  // Copy data
        mufiz_free_cstring(cCopy)                 // Free C memory
        return swiftString
    }
}
```

**Why this works**:
- C-allocated memory is explicitly freed
- Swift String makes its own copy of the data
- No possibility of dangling pointers

## Common Pitfalls Avoided

### ❌ Double-Free
```swift
// BAD: Don't do this
defer { close(fd) }
// ... later ...
close(fd)  // CRASH: descriptor already closed
```

### ✅ Single Close
```swift
// GOOD: Each descriptor closed exactly once
close(fd)
// OR use defer, not both
```

---

### ❌ Use After Free
```swift
// BAD: Don't do this
let cString = strdup(swiftString)
free(cString)
print(String(cString: cString))  // CRASH: reading freed memory
```

### ✅ Copy Before Free
```swift
// GOOD: Copy before freeing
let cString = mufiz_strdup(ptr)
let copy = String(cString: cString)  // Makes Swift copy
mufiz_free_cstring(cString)          // Safe to free
print(copy)                          // Using Swift copy
```

---

### ❌ Race Conditions
```swift
// BAD: Don't do this
class UnsafeBridge {
    func interpret(_ code: String) {
        // Multiple threads can call this simultaneously
        mufiz_interpret(code)  // CRASH: state corruption
    }
}
```

### ✅ Actor Serialization
```swift
// GOOD: Actor prevents concurrent access
actor SafeBridge {
    func interpret(_ code: String) async {
        // Only one call executes at a time
        await mufiz_interpret(code)
    }
}
```

---

### ❌ Unbounded Growth
```swift
// BAD: Don't do this
func repl() {
    while true {
        let result = interpret(readInput())
        // Autoreleased objects accumulate
    }
}
```

### ✅ Autorelease Pool
```swift
// GOOD: Clean up after each iteration
func repl() {
    while true {
        autoreleasepool {
            let result = interpret(readInput())
            // Objects freed at end of pool scope
        }
    }
}
```

## Testing Memory Safety

### Check for Leaks

```bash
# Run with leak detection enabled
leaks --atExit -- swift run FerrufiApp

# Or use Instruments
instruments -t Leaks FerrufiApp
```

### Check for Crashes

```bash
# Enable address sanitizer
swift build -Xswiftc -sanitize=address

# Run with crash detection
swift run FerrufiApp
```

### Monitor Memory Usage

```swift
// In the runtime
await MufiBridge.shared.printMemoryStats()

// Check for leaks
let hasLeaks = await MufiBridge.shared.hasMemoryLeaks()
if hasLeaks {
    print("Warning: Memory leaks detected!")
}
```

## Runtime Lifecycle

### Initialization (App Startup)
```swift
// Called once in applicationDidFinishLaunching
try await MufiBridge.shared.initialize(
    enableLeakDetection: false,
    enableTracking: false,
    enableSafety: true
)
```

### Usage (During App Lifetime)
```swift
// Can be called many times safely
let (status, output) = try await MufiBridge.shared.interpret(code)
```

### Deinitialization (App Shutdown)
```swift
// Called once in applicationWillTerminate
await MufiBridge.shared.deinitialize()
```

## Best Practices

1. **Never bypass safety checks** - The validation exists for a reason
2. **Use timeouts** - Prevent infinite loops from hanging the app
3. **Validate input** - Check for null bytes, size limits, encoding issues
4. **Handle errors gracefully** - Don't crash on invalid input
5. **Test edge cases** - Empty strings, very long strings, special characters
6. **Monitor memory** - Check for leaks periodically
7. **Use actors** - Let Swift manage thread safety
8. **Clean up resources** - Close descriptors, free memory, cancel tasks

## Performance Considerations

### Memory Usage
- Each REPL call uses ~4KB for the output buffer
- Autoreleasepool prevents accumulation
- Typical usage: < 1MB for REPL state

### CPU Usage
- Interpretation runs on background thread (`.userInitiated` priority)
- UI stays responsive during execution
- Timeouts prevent runaway computation

### Thread Safety
- Actor serialization adds minimal overhead
- Background thread prevents UI blocking
- Pipe I/O is efficient for typical output sizes

## Debugging Memory Issues

### Enable Leak Detection
```swift
try await MufiBridge.shared.initialize(
    enableLeakDetection: true,  // Enable this
    enableTracking: true,       // And this
    enableSafety: true
)
```

### Check Stats
```swift
await MufiBridge.shared.printMemoryStats()
```

### Find Crashes
Look for:
- Segfaults (SIGSEGV) → null pointer access
- Bus errors (SIGBUS) → alignment issues
- Abort (SIGABRT) → assertion failures

Check:
- Is runtime initialized?
- Is input valid UTF-8?
- Are descriptors managed correctly?
- Is there a race condition?

## Summary

The Mufi REPL integration uses multiple layers of safety:
- ✅ Swift string lifetime management with `withCString`
- ✅ Explicit descriptor cleanup
- ✅ Actor-based serialization
- ✅ Autoreleasepool for each call
- ✅ Input validation before C calls
- ✅ Timeout protection
- ✅ State validation
- ✅ Proper C memory management

This ensures stable, crash-free operation even with invalid input or edge cases.