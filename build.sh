#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_VERSION="${APP_VERSION:-$(tr -d '[:space:]' < "$DIR/VERSION")}"

if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "🦀 1. Building Rust Core Engine (v$APP_VERSION, release)..."
cd "$DIR/core"
if [ "${UNIVERSAL:-0}" = "1" ]; then
    cargo build --release --target aarch64-apple-darwin ${CARGO_FLAGS:-}
    cargo build --release --target x86_64-apple-darwin ${CARGO_FLAGS:-}
    mkdir -p "$DIR/core/target/release"
    lipo -create \
        "$DIR/core/target/aarch64-apple-darwin/release/libcleaner_core.dylib" \
        "$DIR/core/target/x86_64-apple-darwin/release/libcleaner_core.dylib" \
        -output "$DIR/core/target/release/libcleaner_core.dylib"
else
    cargo build --release ${CARGO_FLAGS:-}
fi

echo "🍏 2. Building Native SwiftUI App (release, size-optimized)..."
cd "$DIR/app"
if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64 -Xswiftc -Osize -Xlinker -dead_strip
    SWIFT_BIN="$DIR/app/.build/apple/Products/Release/Ren"
else
    swift build -c release -Xswiftc -Osize -Xlinker -dead_strip
    SWIFT_BIN="$DIR/app/.build/release/Ren"
fi

echo "📦 3. Assembling Ren.app bundle..."
APP_DIR="$DIR/dist/Ren.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Frameworks"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary, dylib, and app icon
cp "$SWIFT_BIN" "$APP_DIR/Contents/MacOS/Ren"
cp "$DIR/core/target/release/libcleaner_core.dylib" "$APP_DIR/Contents/Frameworks/libcleaner_core.dylib"
if [ -f "$DIR/assets/AppIcon.icns" ]; then
    cp "$DIR/assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Rewrite embedded dylib path so Ren.app is fully relocatable
OLD_DYLIB="$(otool -L "$APP_DIR/Contents/MacOS/Ren" | awk '/libcleaner_core\.dylib/ {print $1; exit}')"
if [ -n "$OLD_DYLIB" ]; then
    install_name_tool -change \
      "$OLD_DYLIB" \
      "@executable_path/../Frameworks/libcleaner_core.dylib" \
      "$APP_DIR/Contents/MacOS/Ren"
fi

# Strip local/debug symbol tables to minimize bundle size
strip "$APP_DIR/Contents/MacOS/Ren"
strip -x "$APP_DIR/Contents/Frameworks/libcleaner_core.dylib"

# Write Info.plist
cat << EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Ren</string>
    <key>CFBundleIdentifier</key>
    <string>com.ren.cleaner</string>
    <key>CFBundleName</key>
    <string>Ren</string>
    <key>CFBundleDisplayName</key>
    <string>Ren</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign so Apple Silicon & Gatekeeper accept the stripped/relocated binary
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

# Optionally build distributable DMG & ZIP packages when PACKAGE=1
if [ "${PACKAGE:-0}" = "1" ]; then
    ARCH_LABEL="${ARCH_LABEL:-$([ "${UNIVERSAL:-0}" = "1" ] && echo "universal" || uname -m)}"
    PKG_BASE="$DIR/dist/Ren-v${APP_VERSION}-macos-${ARCH_LABEL}"

    echo "💿 4. Packaging ${PKG_BASE}.dmg and .zip..."
    rm -f "${PKG_BASE}.dmg" "${PKG_BASE}.zip" "${PKG_BASE}.sha256"

    # ZIP archive (preserves macOS bundle metadata)
    ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "${PKG_BASE}.zip"

    # DMG with /Applications drag-and-drop symlink
    DMG_STAGE="$(mktemp -d)"
    cp -R "$APP_DIR" "$DMG_STAGE/Ren.app"
    ln -s /Applications "$DMG_STAGE/Applications"
    hdiutil create -volname "Ren ${APP_VERSION}" -srcfolder "$DMG_STAGE" -ov -format UDZO "${PKG_BASE}.dmg" >/dev/null
    rm -rf "$DMG_STAGE"

    (cd "$DIR/dist" && shasum -a 256 "$(basename "${PKG_BASE}.dmg")" "$(basename "${PKG_BASE}.zip")" > "$(basename "${PKG_BASE}.sha256")")
fi

echo ""
echo "✨ Ren v${APP_VERSION} successfully assembled!"
echo "   Location: $APP_DIR"
echo "   Total App Size: $(du -sh "$APP_DIR" | cut -f1)"
