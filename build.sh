#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

echo "🦀 1. Building Rust Core Engine (release)..."
cd "$DIR/core"
cargo build --release ${CARGO_FLAGS:-}

echo "🍏 2. Building Native SwiftUI App (release, size-optimized)..."
cd "$DIR/app"
swift build -c release -Xswiftc -Osize -Xlinker -dead_strip

echo "📦 3. Assembling Ren.app bundle..."
APP_DIR="$DIR/dist/Ren.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Frameworks"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary, dylib, and app icon
cp "$DIR/app/.build/release/Ren" "$APP_DIR/Contents/MacOS/Ren"
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
cat << 'EOF' > "$APP_DIR/Contents/Info.plist"
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
    <string>0.1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "✨ Ren.app successfully assembled!"
echo "   Location: $APP_DIR"
echo "   Total App Size: $(du -sh "$APP_DIR" | cut -f1)"
