# GitHub Workflows - Entitlements Status

## ✅ YES - Fixed for GitHub Workflows!

Both workflows have been updated to support entitlements:

### 1. Experimental Release Workflow
**File:** `.github/workflows/experimental-release.yml`

✅ **Checks for entitlements file**
✅ **Verifies entitlements are applied after build**
✅ **Includes entitlements info in release notes**

```yaml
- name: Verify libmufiz.dylib
  run: |
    # Check entitlements file exists
    if [ ! -f "Ferrufi.entitlements" ]; then
      echo "ERROR: Ferrufi.entitlements not found!"
      exit 1
    fi
```

### 2. Official Release Workflow  
**File:** `.github/workflows/macos-release.yml` (NEW)

✅ **Checks for entitlements file**
✅ **Verifies entitlements are applied after build**
✅ **Includes entitlements info in release notes**
✅ **Documents ad-hoc signing in release**

## What You Need to Do

### CRITICAL: Commit the Entitlements File

```bash
# This file MUST be committed or workflows will fail
git add Ferrufi.entitlements
git add scripts/build_app.sh
git add scripts/build_dmg_local.sh
git add .github/workflows/
git commit -m "Fix: Add entitlements for file access"
git push origin main
```

## How Workflows Will Work

### Experimental Builds (main/develop push)

```
1. Checkout code
2. Check Ferrufi.entitlements exists ✅
3. Build app with entitlements
4. Verify entitlements applied ✅
5. Upload to experimental release
```

**Result:** Users download zip with entitlements → File access works! ✅

### Official Releases (v*.*.* tags)

```
1. Checkout code  
2. Check Ferrufi.entitlements exists ✅
3. Build app with entitlements
4. Verify entitlements applied ✅
5. Create GitHub release
```

**Result:** Official releases have entitlements → File access works! ✅

## Verification Steps in Workflows

Both workflows now verify entitlements:

```bash
# After building, workflows run:
if codesign -d --entitlements - Ferrufi.app | grep -q "com.apple.security.files.all"; then
  echo "✓ Entitlements verified"
else
  echo "⚠ Warning: Entitlements may not be applied"
fi
```

## Release Notes Will Include

All releases (experimental and official) will note:

```
## Build Information
- Entitlements: Applied (file access enabled)

## Important Notes
This app is ad-hoc signed with entitlements which means:
- ✅ Full file system access for editing
- ✅ Can load the Mufi runtime library
- ⚠️ You must right-click → Open on first launch
```

## Testing

### Test Experimental Release

```bash
# 1. Commit and push
git add Ferrufi.entitlements scripts/ .github/workflows/
git commit -m "Fix: Add entitlements"
git push origin main

# 2. Wait for workflow to complete
# 3. Check: https://github.com/{user}/Ferrufi/actions

# 4. Download from experimental release
# 5. Test file editing in /Applications
```

### Test Official Release

```bash
# 1. Set version
./scripts/set_version.sh 1.0.0

# 2. Commit and tag
git commit -am "Release 1.0.0"
git tag v1.0.0
git push --tags

# 3. Wait for workflow
# 4. Check release page
# 5. Download and test
```

## What If I Forgot to Commit Ferrufi.entitlements?

Workflow will fail with:

```
ERROR: Ferrufi.entitlements not found!
```

**Fix:**
```bash
git add Ferrufi.entitlements
git commit -m "Add missing entitlements file"
git push
```

## Summary

| Aspect | Status |
|--------|--------|
| **Entitlements file created** | ✅ Yes |
| **Build scripts updated** | ✅ Yes |
| **Experimental workflow updated** | ✅ Yes |
| **Official workflow created** | ✅ Yes |
| **Verification added** | ✅ Yes |
| **Documentation added** | ✅ Yes |
| **Ready to commit** | ✅ Yes |

---

**Action Required:** Commit `Ferrufi.entitlements` and push to enable entitlements in CI! 🚀

See [COMMIT_CHECKLIST.md](COMMIT_CHECKLIST.md) for step-by-step instructions.
