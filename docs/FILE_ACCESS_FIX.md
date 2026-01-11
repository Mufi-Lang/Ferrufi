# File Access Fix - Entitlements Configuration

## Problem

When Ferrufi was installed in `/Applications`, users could no longer edit files. The app would open but file operations (create, edit, save) would fail or be restricted.

## Root Cause

macOS applies strict security policies to apps in `/Applications`, even if they're unsigned. Without proper **entitlements**, the app is effectively sandboxed and cannot:

- Read or write user files
- Access documents, downloads, or other folders
- Load external dynamic libraries (like `libmufiz.dylib`)

## Solution

We now **ad-hoc sign** the app with an entitlements file that grants necessary permissions:

### Entitlements File: `Ferrufi.entitlements`

This file defines what permissions the app needs:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Disable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <false/>

    <!-- Allow reading and writing files chosen by the user -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Allow reading and writing to Downloads, Documents, etc. -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>

    <!-- Allow access to all files (broad permissions) -->
    <key>com.apple.security.files.all</key>
    <true/>

    <!-- Disable library validation (needed for libmufiz.dylib) -->
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>

    <!-- Allow loading unsigned libraries -->
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>

    <!-- Allow dyld environment variables -->
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>

    <!-- Network access -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- Allow JIT compilation -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
</dict>
</plist>
```

### Build Scripts Updated

Both `build_app.sh` and `build_dmg_local.sh` now automatically:

1. Sign the app with ad-hoc signature (`-` identity)
2. Embed the entitlements file
3. Sign `libmufiz.dylib` as well

```bash
# Ad-hoc sign with entitlements
codesign --force --sign "-" \
  --entitlements Ferrufi.entitlements \
  --deep Ferrufi.app
```

## What is Ad-Hoc Signing?

Ad-hoc signing (`-` identity) means:
- ✅ App gets a local signature with entitlements
- ✅ Entitlements are enforced by macOS
- ✅ No Apple Developer certificate needed
- ✅ Free and automatic
- ⚠️ Still requires user approval (right-click → Open first time)
- ⚠️ Not distributable outside your organization

## Verification

Check if entitlements are applied:

```bash
# View entitlements
codesign -d --entitlements - /Applications/Ferrufi.app

# Verify signature
codesign -vv /Applications/Ferrufi.app

# Expected output:
# /Applications/Ferrufi.app: valid on disk
# /Applications/Ferrufi.app: satisfies its Designated Requirement
```

## Key Entitlements Explained

| Entitlement | Purpose |
|-------------|---------|
| `com.apple.security.app-sandbox` = `false` | Disables App Sandbox completely |
| `com.apple.security.files.all` | Access to all user files |
| `com.apple.security.files.user-selected.read-write` | Access files user opens/saves |
| `com.apple.security.cs.disable-library-validation` | Load `libmufiz.dylib` without validation |
| `com.apple.security.cs.allow-unsigned-executable-memory` | Allow JIT/dynamic code |
| `com.apple.security.network.client` | Network access for future features |

## Testing

After building with entitlements:

```bash
# Build
./scripts/build_app.sh --zip

# Install
cp -R Ferrufi.app /Applications/
xattr -cr /Applications/Ferrufi.app

# Launch
open /Applications/Ferrufi.app

# Try editing a file - should work now!
```

## Troubleshooting

### Still Can't Edit Files?

1. **Verify entitlements are applied:**
   ```bash
   codesign -d --entitlements - /Applications/Ferrufi.app | grep "com.apple.security.files.all"
   ```
   Should show `[Bool] true`

2. **Check signature is valid:**
   ```bash
   codesign -vv /Applications/Ferrufi.app
   ```
   Should say "valid on disk"

3. **Rebuild with entitlements:**
   ```bash
   rm -rf Ferrufi.app
   ./scripts/build_app.sh
   cp -R Ferrufi.app /Applications/
   xattr -cr /Applications/Ferrufi.app
   ```

### Permission Denied Errors?

Check macOS privacy settings:
1. Go to **System Settings → Privacy & Security**
2. Look for **Files and Folders** or **Full Disk Access**
3. Add Ferrufi if needed

### Entitlements File Not Found?

Make sure `Ferrufi.entitlements` exists in the project root:
```bash
ls -l Ferrufi.entitlements
```

If missing, recreate it with the XML above.

## For Developers

### Building Without Entitlements

If you don't want entitlements (not recommended):

```bash
# Remove or rename the entitlements file
mv Ferrufi.entitlements Ferrufi.entitlements.bak

# Build will skip entitlements
./scripts/build_app.sh
```

### Modifying Entitlements

Edit `Ferrufi.entitlements` to add or remove permissions, then rebuild:

```bash
# Edit entitlements
nano Ferrufi.entitlements

# Rebuild
./scripts/build_app.sh
```

### CI/CD

GitHub workflows automatically apply entitlements during builds. No action needed.

## Security Implications

These entitlements give the app **broad permissions**:
- ✅ Necessary for a code editor/IDE
- ✅ User explicitly approves on first launch
- ⚠️ App can access all user files
- ⚠️ App can load unsigned code (for Mufi runtime)

This is standard for developer tools like VS Code, Xcode, etc.

## Related Documentation

- [Distribution Guide](./DISTRIBUTION.md) - How to distribute the app
- [Build Scripts](../scripts/README.md) - Build script documentation

## Summary

**Problem:** App couldn't edit files in `/Applications`  
**Cause:** Missing entitlements  
**Solution:** Ad-hoc sign with `Ferrufi.entitlements`  
**Result:** Full file access + libmufiz.dylib loading works  

All builds now automatically include entitlements! 🎉