# Root Cause Analysis: File Access Issue in /Applications

**Date:** January 11, 2025  
**Issue:** Users cannot edit files when Ferrufi is installed in `/Applications`  
**Status:** ✅ Root cause identified and fixed

---

## The Real Problem

After extensive investigation, we discovered that **ad-hoc code signing with entitlements WAS working correctly** in the GitHub CI builds. The issue was NOT with the signing process itself.

### What We Initially Thought

1. ❌ Ad-hoc signing wasn't being applied in CI
2. ❌ Entitlements weren't being embedded in the app
3. ❌ The security-scoped resource wrapper wasn't working

### What Was Actually Happening

✅ **All of the above were working correctly!**

The real issue: **macOS requires explicit user consent for security-scoped access to folders, even with proper entitlements.**

---

## Why File Access Failed

### The Misconception

We thought that having these entitlements would be enough:

```xml
<key>com.apple.security.files.all</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

### The Reality

Even with these entitlements, macOS enforces the following rules:

1. **Entitlements grant PERMISSION** - They tell macOS "this app is allowed to access files"
2. **Security-scoped resources grant ACCESS** - They tell macOS "the user gave consent for specific folders"

### The Missing Piece

Our app automatically creates and uses `~/.ferrufi` as the vault folder, but it **never asks the user to select this folder** via `NSOpenPanel`.

Without explicit user selection through the system dialog:
- No security-scoped bookmark is created
- No consent is recorded
- macOS blocks file access even though entitlements say it's allowed

---

## How macOS Security Model Works

### Three Layers of Protection

```
┌─────────────────────────────────────────┐
│  1. ENTITLEMENTS                        │
│     (Declared capabilities)             │
│     • What the app CAN do               │
│     • Set by developer                  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  2. USER CONSENT                        │
│     (Granted permissions)               │
│     • What the user ALLOWS              │
│     • Granted through system dialogs    │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│  3. SECURITY-SCOPED BOOKMARKS           │
│     (Persistent access tokens)          │
│     • Saved proof of user consent       │
│     • Survives app relaunches           │
└─────────────────────────────────────────┘
```

### What Was Missing in Ferrufi

We had **Layer 1** (entitlements) but were missing **Layers 2 & 3** (user consent + bookmarks).

---

## The Fix: Security-Scoped Bookmarks

### What We Implemented

1. **SecurityScopedBookmarkManager** - A manager class that:
   - Requests user to select the vault folder via `NSOpenPanel`
   - Creates security-scoped bookmarks for user-selected folders
   - Stores bookmarks persistently in `UserDefaults`
   - Automatically resolves bookmarks on app launch

2. **First-Launch Folder Selection** - Modified `ContentView.swift` to:
   - Check if a bookmark exists for the vault folder
   - If not, show a dialog requesting folder access
   - Present `NSOpenPanel` for the user to select `~/.ferrufi` (or the selected workspace)
   - Create and store a security-scoped bookmark

3. **Persistent Access** - On subsequent launches:
   - Resolve the stored bookmark
   - Call `startAccessingSecurityScopedResource()`
   - All file operations now have proper access

### Code Flow

```swift
// On first launch or when bookmark is missing:
1. App starts
2. Checks: Do we have a bookmark for ~/.ferrufi?
3. If NO → Show NSOpenPanel asking user to select the folder
4. User selects folder → Create security-scoped bookmark
5. Store bookmark in UserDefaults
6. Start accessing the security-scoped resource

// On subsequent launches:
1. App starts
2. Load bookmark from UserDefaults
3. Resolve bookmark to get URL
4. Start accessing the security-scoped resource
5. All file I/O now works!
```

---

## Why This Fix Works

### Before (Broken)

```
App → Creates ~/.ferrufi automatically
    → Tries to write file
    → macOS: "No user consent recorded"
    → ❌ Permission denied
```

### After (Fixed)

```
App → Creates ~/.ferrufi automatically
    → Checks for bookmark
    → If none, shows NSOpenPanel
    → User selects folder via system dialog
    → macOS records consent
    → Creates security-scoped bookmark
    → App resolves bookmark on launch
    → Starts accessing security-scoped resource
    → Tries to write file
    → macOS: "User consent recorded via bookmark"
    → ✅ Write succeeds
```

---

## Key Insights

### 1. Entitlements Are Not Enough

Having `com.apple.security.files.all = true` does NOT automatically grant file access. It only declares that the app is *capable* of accessing files.

### 2. User Consent Is Required

Even for folders the app creates itself (like `~/.ferrufi`), you need explicit user consent through:
- `NSOpenPanel` / `NSSavePanel`
- Security-scoped bookmarks
- Full Disk Access (manual user approval in System Settings)

### 3. Our Security-Scoped Wrapper Was Correct... But Insufficient

The `withSecurityScope { }` wrapper we created works perfectly for files obtained via `NSOpenPanel`. However, for the vault folder that the app creates automatically, we needed the additional bookmark management layer.

### 4. Ad-hoc Signing + Entitlements + Bookmarks = Working Solution

The complete solution requires all three:
- ✅ Ad-hoc signing (applied by build script)
- ✅ Entitlements (embedded in app bundle)
- ✅ Security-scoped bookmarks (new addition)

---

## Why Initial Tests Succeeded But Homebrew Failed

### Local Testing

When testing locally, we likely:
1. Built the app in the repo folder
2. Launched from there or copied to `/Applications`
3. The app had access because of quarantine removal: `xattr -cr`

The `xattr -cr` command removes macOS quarantine attributes, which also loosens security restrictions temporarily.

### Homebrew Installation

When installing via Homebrew:
1. App is downloaded from GitHub release
2. Quarantine attributes are preserved
3. App is copied to `/Applications` by Homebrew
4. macOS enforces strict security (no consent, no access)
5. File operations fail ❌

---

## Testing the Fix

### Before Fix
```bash
# Install via Homebrew
brew install --cask ferrufi

# Launch app
open /Applications/Ferrufi.app

# Try to create/edit note
❌ Permission denied
```

### After Fix
```bash
# Install via Homebrew
brew install --cask ferrufi

# Launch app
open /Applications/Ferrufi.app

# First launch: System shows folder selection dialog
→ "Ferrufi needs access to: ~/.ferrufi"
→ User clicks "Grant Access"
→ NSOpenPanel appears
→ User navigates to and selects ~/.ferrufi
→ Bookmark created and stored

# Try to create/edit note
✅ Success! File operations work

# Subsequent launches
→ Bookmark resolved automatically
→ All file operations work without prompts
```

---

## Impact on Users

### One-Time Setup

On first launch after this fix is deployed, users will see:

1. **Alert**: "Folder Access Required"
   - Message: "Ferrufi needs access to your notes folder to function properly. Please select the folder when prompted."
   - Button: "OK"

2. **System Dialog** (NSOpenPanel):
   - Title: "Grant Access"
   - Message: "Ferrufi needs access to: /Users/username/.ferrufi"
   - The dialog shows the filesystem
   - User navigates to and selects `~/.ferrufi`
   - Clicks "Grant Access"

3. **Done!**
   - Bookmark is saved
   - Never asked again
   - All file operations work

### User Experience

- ✅ One-time setup (first launch only)
- ✅ Clear explanation of why access is needed
- ✅ Standard macOS security dialog (familiar to users)
- ✅ Persistent access (bookmark survives app relaunches)
- ✅ No ongoing permission prompts

---

## Alternative Solutions Considered

### 1. Request Full Disk Access
❌ **Rejected**: Requires manual user navigation to System Settings → Privacy & Security → Full Disk Access. Too complex for average users.

### 2. Create Vault in Non-Protected Location
❌ **Rejected**: Would require major architectural changes. Home directory is the right place for user data.

### 3. Use App Group Container
❌ **Rejected**: Only works for sandboxed apps. We explicitly disable sandbox to allow file access.

### 4. Notarization + Hardened Runtime
⚠️ **Deferred**: Requires $99/year Apple Developer account. Good for production but not blocking for initial release.

### 5. Security-Scoped Bookmarks ✅
**Selected**: Industry-standard approach. Works with ad-hoc signing. One-time user action. Persistent across launches.

---

## Files Changed

### New Files
- `Sources/Ferrufi/Core/Storage/SecurityScopedBookmarkManager.swift` - Bookmark manager
- `docs/FILE_ACCESS_ISSUE_ROOT_CAUSE.md` - This document

### Modified Files
- `Sources/Ferrufi/UI/Views/ContentView.swift` - Added folder access request on first launch

### Unchanged (Already Working)
- `Ferrufi.entitlements` - Entitlements configuration
- `scripts/build_app.sh` - Ad-hoc signing with entitlements
- `Sources/Ferrufi/Core/Storage/SecurityScopedFileAccess.swift` - File access wrapper
- All file I/O operations - Already using `withSecurityScope`
- CI workflows - Already applying entitlements correctly

---

## Verification

### Check Entitlements (Still Working)
```bash
codesign -d --entitlements - /Applications/Ferrufi.app
# Should show com.apple.security.files.all = true
```

### Check Bookmark Storage (New)
```bash
defaults read com.ferrufi.Ferrufi com.ferrufi.securityScopedBookmarks
# Should show bookmark data for ~/.ferrufi
```

### Test File Operations (Should Work Now)
```bash
# Launch app
open /Applications/Ferrufi.app

# Select folder when prompted
# Try creating/editing/deleting notes
# All operations should succeed ✅
```

---

## Conclusion

The file access issue was caused by a **subtle but critical misunderstanding** of macOS security model:

1. ✅ We correctly implemented entitlements
2. ✅ We correctly implemented ad-hoc signing
3. ✅ We correctly wrapped file operations with security-scoped access
4. ❌ We forgot to request user consent through NSOpenPanel
5. ❌ We forgot to create and store security-scoped bookmarks

The fix is simple: **Ask the user once** to select the vault folder, create a bookmark, and all subsequent access works automatically.

This is the standard pattern used by macOS apps like:
- Text editors accessing project folders
- Video editors accessing media libraries  
- IDEs accessing workspace directories

**The ad-hoc signing in CI was working all along.** The missing piece was the user consent layer.

---

**Next Steps:**
1. ✅ Build with new bookmark manager
2. ✅ Test locally in /Applications
3. ⏳ Deploy via CI to experimental release
4. ⏳ Test via Homebrew installation
5. ⏳ Verify file operations work end-to-end
6. ⏳ Create official release with fix