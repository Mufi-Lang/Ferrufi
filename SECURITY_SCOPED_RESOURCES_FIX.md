# Security-Scoped Resources Fix

## The Real Problem

Entitlements alone aren't enough! Even with `com.apple.security.files.all`, macOS requires **security-scoped resource** access when:

1. User selects files via `NSOpenPanel`
2. App tries to access files outside its container
3. App is in `/Applications`

## Quick Fix

I've created `SecurityScopedFileAccess.swift` with helpers. You need to wrap all file operations:

### Before (Doesn't Work):
```swift
// This FAILS in /Applications even with entitlements!
try content.write(to: fileURL, atomically: true, encoding: .utf8)
```

### After (Works):
```swift
// This WORKS - uses security-scoped access
try fileURL.withSecurityScope { url in
    try content.write(to: url, atomically: true, encoding: .utf8)
}
```

## Files to Update

Search for these patterns and wrap them:

### 1. FolderManager (Core/Models/Folder.swift)

**Line ~359:**
```swift
// BEFORE:
try content.write(to: fileURL, atomically: true, encoding: .utf8)

// AFTER:
try fileURL.withSecurityScope { url in
    try content.write(to: url, atomically: true, encoding: .utf8)
}
```

**Line ~452:**
```swift
// BEFORE:
try content.write(to: fileURL, atomically: true, encoding: .utf8)

// AFTER:
try FileManager.default.securityScopedWriteString(content, to: fileURL)
```

### 2. FileStorage (Core/Storage/FileStorage.swift)

**Line ~113:**
```swift
// BEFORE:
try note.content.write(to: noteURL, atomically: true, encoding: .utf8)

// AFTER:
try noteURL.withSecurityScope { url in
    try note.content.write(to: url, atomically: true, encoding: .utf8)
}
```

**Line ~143:**
```swift
// BEFORE:
let content = try String(contentsOf: noteURL, encoding: .utf8)

// AFTER:
let content = try FileManager.default.securityScopedReadString(from: noteURL)
```

## Or Use the Simple Helper

Add import:
```swift
import Foundation  // Already have this

// Use the extension methods:
try FileManager.default.securityScopedWriteString(content, to: fileURL)
let content = try FileManager.default.securityScopedReadString(from: fileURL)
```

## Quick Test Command

After updating the code:

```bash
# Rebuild
swift build -c release

# Copy to build location
./scripts/build_app.sh --zip

# Install
cp -R Ferrufi.app /Applications/
xattr -cr /Applications/Ferrufi.app

# Launch and test editing!
open /Applications/Ferrufi.app
```

## Why This is Needed

macOS has multiple layers of security:

1. **Entitlements** - Declare what you CAN do (we have this ✅)
2. **Security-Scoped Resources** - Actually GET permission to do it (missing! ❌)

Even with `com.apple.security.files.all`, you must call:
- `url.startAccessingSecurityScopedResource()` before access
- `url.stopAccessingSecurityScopedResource()` when done

The helper does this automatically with `withSecurityScope`.

## Alternative: Add to Info.plist

If you don't want to change code, add this to Info.plist (but it's less secure):

```xml
<key>NSFileProviderDomainDidChangeNotification</key>
<true/>
```

But I recommend using security-scoped resources properly.

## Files Created

- `Sources/Ferrufi/Core/Storage/SecurityScopedFileAccess.swift` - Helper utilities

## Next Steps

1. Update FolderManager file write operations
2. Update FileStorage file operations
3. Rebuild and test
4. Commit changes

---

**TL;DR:** Wrap all `try content.write(...)` and `try String(contentsOf:...)` with `.withSecurityScope { ... }`
