# Commit Checklist - Entitlements Fix

## Files to Commit

Run this to add all necessary files:

```bash
# Add entitlements file (CRITICAL - workflows need this!)
git add Ferrufi.entitlements

# Add updated build scripts
git add scripts/build_app.sh
git add scripts/build_dmg_local.sh

# Add workflows
git add .github/workflows/macos-release.yml
git add .github/workflows/experimental-release.yml

# Add documentation
git add docs/FILE_ACCESS_FIX.md
git add ENTITLEMENTS_FIX_SUMMARY.md
git add README.md

# Add this checklist
git add COMMIT_CHECKLIST.md

# Commit everything
git commit -m "Fix: Add entitlements for file access in /Applications

- Add Ferrufi.entitlements with file system permissions
- Update build scripts to apply entitlements via ad-hoc signing
- Update workflows to verify entitlements are applied
- Add documentation explaining the fix
- Resolves issue where app couldn't edit files in /Applications"

# Push to GitHub
git push origin main
```

## Verification

Before pushing, verify:

```bash
# 1. Check entitlements file exists
ls -l Ferrufi.entitlements

# 2. Check workflows reference entitlements
grep -n "entitlements" .github/workflows/*.yml

# 3. Check build scripts apply entitlements
grep -n "entitlements" scripts/build_app.sh

# 4. Build locally to test
./scripts/build_app.sh --zip
codesign -d --entitlements - Ferrufi.app | grep "files.all"
```

## Critical Files

These MUST be committed or workflows will fail:

- ✅ `Ferrufi.entitlements` - Required by build scripts
- ✅ `scripts/build_app.sh` - Updated to apply entitlements  
- ✅ `.github/workflows/macos-release.yml` - Official releases
- ✅ `.github/workflows/experimental-release.yml` - Experimental builds

## What Happens After Push

1. **Experimental Release:**
   - Push to `main` triggers experimental workflow
   - Builds app with entitlements
   - Updates `experimental` release
   - Users can download and test

2. **Official Release:**
   - Create tag: `git tag v1.0.0 && git push --tags`
   - Triggers official release workflow
   - Creates GitHub release with zip
   - Includes entitlements automatically

## Testing Workflow Locally

Simulate CI environment:

```bash
# Clean build
rm -rf .build Ferrufi.app *.zip

# Run build as CI would
./scripts/build_app.sh --version 0.0.1 --zip

# Verify entitlements
codesign -d --entitlements - Ferrufi.app

# Install and test
cp -R Ferrufi.app /Applications/
xattr -cr /Applications/Ferrufi.app
open /Applications/Ferrufi.app
# Try editing a file!
```

## Quick Commit Command

```bash
git add Ferrufi.entitlements scripts/ .github/workflows/ docs/ *.md && \
git commit -m "Fix: Add entitlements for file access" && \
git push origin main
```

---

**Don't forget to commit `Ferrufi.entitlements` or the workflows will fail!** ⚠️
