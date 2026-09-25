#!/bin/sh
# Usage: ./build.sh            version from the latest git tag (v1.2.0 → 1.2.0)
#        VERSION=1.2.0 ./build.sh
set -e
cd "$(dirname "$0")"
VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}
VERSION=${VERSION:-0.0.0}
mkdir -p MouseSnap.app/Contents/MacOS MouseSnap.app/Contents/Resources
cp AppIcon.icns Help/*.png MouseSnap.app/Contents/Resources/
# Universal binary (Apple silicon + Intel), runs on macOS 13+.
swiftc -O -target arm64-apple-macos13 main.swift -o /tmp/mousesnap-arm64
swiftc -O -target x86_64-apple-macos13 main.swift -o /tmp/mousesnap-x86_64
lipo -create /tmp/mousesnap-arm64 /tmp/mousesnap-x86_64 -output MouseSnap.app/Contents/MacOS/MouseSnap
cat > MouseSnap.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>MouseSnap</string>
<key>CFBundleExecutable</key><string>MouseSnap</string>
<key>CFBundleIdentifier</key><string>local.mousesnap</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign -s - --force MouseSnap.app
