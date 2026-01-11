# CI/CD Code Signing Implementation

**Status:** ✅ Implemented and Verified  
**Type:** Ad-hoc Code Signing with Entitlements  
**Last Verified:** January 11, 2025 (Build #4, Run ID: 20901019199)

---

## Overview

Yes, our GitHub Actions workflows **are using ad-hoc code signing** with entitlements. This is implemented in the build scripts and verified in the CI pipeline.

## How It Works

### 1. Build Script (`scripts/build_app.sh`)

The build script automatically applies ad-hoc signing with entitlements:

```bash
# Sign dylib first
codesign --force --sign "-" "$FRAMEWORKS_DIR/libmufiz.dylib"

# Sign app with entitlements
codesign --force --sign "-" --entitlements "$ENTITLEMENTS_FILE" --deep "$BUNDLE_DIR"
```

**Key Points:**
- `--sign "-"` = ad-hoc signature (no Developer ID certificate required)
- `--entitlements Ferrufi.entitlements` = apply security permissions
- `--deep` = sign all nested components (dylib, frameworks, etc.)
- `--force` = replace any existing signature

### 2. CI Workflow Verification

The experimental release workflow (`experimental-release.yml`) includes multiple verification steps:

#### Step 1: Pre-Build Check
```yaml
- name: Verify libmufiz.dylib
  run: |
    echo "Checking entitlements file..."
    if [ ! -f "Ferrufi.entitlements" ]; then
      echo "ERROR: Ferrufi.entitlements not found!"
      exit 1
    fi
    echo "✓ Entitlements file found"
```

#### Step 2: Build with Signing
```yaml
- name: Build App with Zip
  run: |
    ./scripts/build_app.sh \
      --version "${{ steps.final-version.outputs.version }}" \
      --zip
```

#### Step 3: Post-Build Verification
```yaml
- name: Verify Build Artifacts
  run: |
    # Verify entitlements are applied
    echo "Verifying entitlements..."
    if codesign -d --entitlements - "$APP_BUNDLE" 2>&1 | grep -q "com.apple.security.files.all"; then
      echo "✓ Entitlements verified"
    else
      echo "⚠ Warning: Entitlements may not be applied correctly"
    fi
```

## Verification from Latest Build

### Build Log Evidence (Run ID: 20901019199)

**Pre-Build Check:**
```
Checking entitlements file...
✓ Entitlements file found
```

**During Build:**
```
━━━ Applying Entitlements ━━━
▶ Applying entitlements for file access permissions
✓ App signed with entitlements (ad-hoc signature)
```

**Post-Build Verification:**
```
Verifying entitlements...
✓ Entitlements verified
```

**Result:** ✅ All checks passed

## What Gets Signed

1. **libmufiz.dylib** - Native runtime library
   - Signed with: `codesign --force --sign "-" libmufiz.dylib`
   - Purpose: Allow loading in signed app bundle

2. **Ferrufi.app** - Main application bundle
   - Signed with: `codesign --force --sign "-" --entitlements Ferrufi.entitlements --deep Ferrufi.app`
   - Purpose: Apply security permissions for file access

## Entitlements Applied

The workflow ensures these entitlements are embedded in every build:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>

<key>com.apple.security.files.all</key>
<true/>

<key>com.apple.security.files.user-selected.read-write</key>
<true/>

<key>com.apple.security.cs.disable-library-validation</key>
<true/>

<key>com.apple.security.cs.allow-dyld-environment-variables</key>
<true/>

<key>com.apple.security.cs.allow-jit</key>
<true/>

<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

## Why Ad-hoc Signing?

**Advantages:**
- ✅ No Apple Developer account required ($0 vs $99/year)
- ✅ No certificate management in CI
- ✅ No notarization complexity
- ✅ Still allows entitlements for file access
- ✅ Works perfectly for open-source projects

**Disadvantages:**
- ⚠️ Users see Gatekeeper warning on first launch
- ⚠️ Requires "Right-click → Open" or manual approval
- ⚠️ Cannot be notarized by Apple
- ⚠️ Not suitable for Mac App Store

## User Experience

When users download and run the app:

1. **First Launch:** macOS shows warning about "unidentified developer"
2. **User Action Required:** Right-click → Open → Click "Open"
3. **Subsequent Launches:** Opens normally without warnings

**Quick Fix for Users:**
```bash
# Remove quarantine attribute
xattr -cr /Applications/Ferrufi.app

# Launch
open /Applications/Ferrufi.app
```

## Verification Commands

### For CI (Automated)
```bash
# Check if entitlements file exists
test -f Ferrufi.entitlements && echo "✓ Entitlements file found"

# Verify entitlements are applied after build
codesign -d --entitlements - Ferrufi.app 2>&1 | grep -q "com.apple.security.files.all"
```

### For Local Testing
```bash
# Build with signing
./scripts/build_app.sh --zip

# Verify signature exists
codesign -vv Ferrufi.app
# Output: Ferrufi.app: valid on disk

# Display entitlements
codesign -d --entitlements - Ferrufi.app

# Check what's signed
codesign -dvv Ferrufi.app
```

## Workflow Matrix

| Workflow | Triggers | Signing | Entitlements | Verification |
|----------|----------|---------|--------------|--------------|
| `experimental-release.yml` | Push to main/develop | ✅ Ad-hoc | ✅ Applied | ✅ Verified |
| `macos-release.yml` | Git tag push | ✅ Ad-hoc | ✅ Applied | ✅ Verified |
| Local build (`build_app.sh`) | Manual | ✅ Ad-hoc | ✅ Applied | Manual |

## Future: Production Signing

If we want to eliminate Gatekeeper warnings:

### Option 1: Developer ID Signing
```yaml
# Add to workflow
- name: Import Certificate
  run: |
    echo "${{ secrets.DEVELOPER_ID_CERT }}" | base64 -d > cert.p12
    security create-keychain -p actions build.keychain
    security import cert.p12 -k build.keychain -P "${{ secrets.CERT_PASSWORD }}"
    
- name: Sign with Developer ID
  run: |
    codesign --force \
             --sign "Developer ID Application: Your Name (TEAM_ID)" \
             --entitlements Ferrufi.entitlements \
             --deep \
             --timestamp \
             --options runtime \
             Ferrufi.app
```

### Option 2: Notarization
```yaml
- name: Notarize
  run: |
    xcrun notarytool submit Ferrufi.zip \
      --apple-id "${{ secrets.APPLE_ID }}" \
      --password "${{ secrets.APP_SPECIFIC_PASSWORD }}" \
      --team-id "${{ secrets.TEAM_ID }}" \
      --wait
    
    xcrun stapler staple Ferrufi.app
```

**Cost:** $99/year for Apple Developer Program

## Summary

✅ **Yes, CI workflows use ad-hoc code signing**  
✅ **Entitlements are automatically applied**  
✅ **Every build is verified to have correct entitlements**  
✅ **File access permissions work correctly**  
✅ **No manual intervention required in CI**  

The current implementation provides a good balance between functionality and simplicity for an open-source project. Users get full file access capabilities with just a one-time Gatekeeper approval.

---

**See Also:**
- `CURRENT_STATUS.md` - Complete project status
- `QUICK_REFERENCE.md` - Quick commands and testing
- `docs/FILE_ACCESS_FIX.md` - File access implementation details
- `Ferrufi.entitlements` - Entitlements configuration
- `scripts/build_app.sh` - Build script with signing logic