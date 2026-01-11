# File Access Fix Applied - Entitlements

## Problem Solved

✅ **Fixed:** App can now edit files when installed in `/Applications`

## What Was Wrong

When Ferrufi was in `/Applications`, macOS applied strict sandboxing that prevented:
- Reading/writing user files
- Accessing Documents, Downloads, etc.
- Loading `libmufiz.dylib` (unsigned library)

## The Fix

Added **entitlements** via ad-hoc code signing:

1. Created `Ferrufi.entitlements` with necessary permissions
2. Updated build scripts to apply entitlements automatically
3. App now has full file access and can load the Mufi runtime

## What Changed

### New File
- `Ferrufi.entitlements` - Defines app permissions

### Updated Scripts
- `scripts/build_app.sh` - Now applies entitlements
- `scripts/build_dmg_local.sh` - Now applies entitlements

### Documentation
- `docs/FILE_ACCESS_FIX.md` - Complete explanation
- `README.md` - Added note about entitlements

## Key Entitlements Applied

```xml
<key>com.apple.security.app-sandbox</key>
<false/>  <!-- Disable sandbox -->

<key>com.apple.security.files.all</key>
<true/>   <!-- Access all files -->

<key>com.apple.security.cs.disable-library-validation</key>
<true/>   <!-- Load libmufiz.dylib -->
```

## How It Works

**Ad-Hoc Signing:**
- Uses local signature (no Apple Developer cert needed)
- Embeds entitlements that macOS enforces
- Free and automatic
- Still requires user approval first time

```bash
# This happens automatically in build scripts:
codesign --force --sign "-" \
  --entitlements Ferrufi.entitlements \
  --deep Ferrufi.app
```

## For Users

Nothing changes! Just:
1. Download and extract the app
2. Right-click → Open (first time only)
3. App now works in `/Applications` ✅

## Verify It Works

```bash
# Check entitlements
codesign -d --entitlements - /Applications/Ferrufi.app

# Should show:
# [Key] com.apple.security.files.all
# [Value] [Bool] true
```

## Testing Done

✅ Built app with entitlements  
✅ Verified entitlements embedded  
✅ Installed in /Applications  
✅ Signature validates  
✅ File access works  

## Next Steps

1. **Current users:** Rebuild and reinstall
   ```bash
   ./scripts/build_app.sh --zip
   cp -R Ferrufi.app /Applications/
   xattr -cr /Applications/Ferrufi.app
   ```

2. **New builds:** Automatic - entitlements are always applied

3. **CI/CD:** Workflows automatically apply entitlements

## Security Note

These entitlements give broad permissions (standard for IDEs):
- ✅ Access to all user files
- ✅ Load unsigned libraries
- ✅ User must approve first launch
- ✅ Required for code editor functionality

## Related Docs

- [FILE_ACCESS_FIX.md](docs/FILE_ACCESS_FIX.md) - Full technical details
- [DISTRIBUTION_QUICKSTART.md](DISTRIBUTION_QUICKSTART.md) - Distribution guide

---

**Problem:** Can't edit files in Applications ❌  
**Solution:** Ad-hoc sign with entitlements ✅  
**Status:** Fixed and automatic in all builds 🎉
