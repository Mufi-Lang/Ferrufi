#!/bin/zsh

# Generate Xcode project from Package.swift
swift package generate-xcodeproj

# Build the app for Release
xcodebuild -project FerrufiApp.xcodeproj \
  -scheme IronAppScheme \
  -configuration Release \
  -derivedDataPath build/xcode

# Copy Mufi dynamic library into build outputs so the app can find it at runtime.
# This helper will copy include/libmufiz.dylib into .build/*/(debug|release)/ directories.
./scripts/copy_mufiz_dylib.sh || echo "Warning: failed to copy libmufiz.dylib into build outputs"

# Additionally, bundle the dynamic library into the Xcode-built .app so the app can find it when launched.
RELEASE_DIR="build/xcode/Build/Products/Release"
APP_BUNDLE="$(ls -d "${RELEASE_DIR}"/*.app 2>/dev/null | head -n 1 || true)"
if [ -n "$APP_BUNDLE" ]; then
  echo "Bundling libmufiz.dylib into $APP_BUNDLE/Contents/Frameworks"
  mkdir -p "$APP_BUNDLE/Contents/Frameworks"
  cp -f include/libmufiz.dylib "$APP_BUNDLE/Contents/Frameworks/" || echo "Warning: failed to copy include/libmufiz.dylib into $APP_BUNDLE/Contents/Frameworks/"
  # Set install name/id of the dylib to @rpath so the app can find it via rpath
  install_name_tool -id @rpath/libmufiz.dylib "$APP_BUNDLE/Contents/Frameworks/libmufiz.dylib" || true

  # Ensure the app executable has an rpath pointing to its Frameworks folder
  APP_NAME="$(basename "$APP_BUNDLE" .app)"
  APP_EXECUTABLE="$APP_NAME"
  if [ -f "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE" ]; then
    install_name_tool -add_rpath @executable_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/$APP_EXECUTABLE" || true
  fi

  # Optionally codesign the embedded dylib and the app bundle if CODESIGN_IDENTITY is provided.
  # Set CODESIGN_IDENTITY in the environment (e.g. export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)")
  if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    if command -v codesign >/dev/null 2>&1; then
      echo "Signing libmufiz.dylib with identity $CODESIGN_IDENTITY"
      codesign --force --sign "$CODESIGN_IDENTITY" --timestamp=none "$APP_BUNDLE/Contents/Frameworks/libmufiz.dylib" || echo "Warning: failed to sign libmufiz.dylib"
      echo "Signing app bundle $APP_BUNDLE"
      # Use --deep to ensure nested code is signed; adjust as needed for your signing policies
      codesign --force --sign "$CODESIGN_IDENTITY" --timestamp=none --deep "$APP_BUNDLE" || echo "Warning: failed to sign app bundle"
      echo "Verifying code signature (non-fatal if verification fails)"
      codesign --verify --deep --strict "$APP_BUNDLE" || echo "Warning: codesign verification failed (non-fatal)"
    else
      echo "codesign not found; skipping code signing step"
    fi
  else
    echo "CODESIGN_IDENTITY not set; skipping code signing"
  fi

  echo "Bundled libmufiz.dylib into $APP_BUNDLE"

  # Create a DMG for the release
  echo "Creating DMG archive..."
  STAGING_DIR="build/dmg_staging"
  mkdir -p "$STAGING_DIR"
  cp -R "$APP_BUNDLE" "$STAGING_DIR/"
  ln -s /Applications "$STAGING_DIR/Applications"

  VOL_NAME="Ferrufi ${VERSION}"
  DMG_NAME="Ferrufi-${VERSION}.dmg"

hdiutil create -volname "${VOL_NAME}" -srcfolder "$STAGING_DIR" -ov -format UDZO "${RELEASE_DIR}/${DMG_NAME}"

  echo "Created ${DMG_NAME} in $RELEASE_DIR"

else
  echo "No .app found under build/xcode/Build/Products — skipping bundling and packaging step"
fi

# The .app will appear under:
# build/xcode/Build/Products/Release/FerrufiApp.app
# The DMG archive will be in the same directory.
