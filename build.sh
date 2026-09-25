#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p MouseSnap.app/Contents/MacOS MouseSnap.app/Contents/Resources
cp AppIcon.icns MouseSnap.app/Contents/Resources/
swiftc -O main.swift -o MouseSnap.app/Contents/MacOS/MouseSnap
cat > MouseSnap.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>MouseSnap</string>
<key>CFBundleExecutable</key><string>MouseSnap</string>
<key>CFBundleIdentifier</key><string>local.mousesnap</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
codesign -s - --force MouseSnap.app
