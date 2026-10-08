#!/bin/zsh
# Build script ของ Argard — คอมไพล์ด้วย swiftc แล้วแพ็คเป็น .app
# ใช้แค่ Command Line Tools (ไม่ต้องมี Xcode เต็ม)
# วิธีใช้:  ./build.sh   จะได้ build/Argard.app

set -euo pipefail
cd "$(dirname "$0")"

APP="build/Argard.app"
MACOS_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "▸ Compiling Swift sources..."
mkdir -p "$MACOS_DIR" "$RES_DIR"

swiftc -swift-version 5 -O \
    -target arm64-apple-macos13.0 \
    -o "$MACOS_DIR/Argard" \
    ArgardApp.swift \
    ContentView.swift \
    Models/*.swift \
    Services/*.swift \
    Views/*.swift \
    -framework SwiftUI -framework AppKit

echo "▸ Assembling bundle..."
cp Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"
fi

echo "▸ Ad-hoc codesign (ให้เปิดได้แบบไม่ต้องขึ้น App Store)..."
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✓ Built: $(cd . && pwd)/$APP"
