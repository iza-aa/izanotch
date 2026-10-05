#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_BUNDLE="$PROJECT_ROOT/bin/GrokbotTestStudio.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "==> Building Grokbot Test Studio (Standalone)..."
mkdir -p "$MACOS_DIR"

swiftc -parse-as-library -framework SwiftUI -framework AppKit \
    "$PROJECT_ROOT/boringNotch/components/CursorAssistant/GrokbotNotchCharacterView.swift" \
    "$PROJECT_ROOT/scripts/test_grokbot_studio.swift" \
    -o "$MACOS_DIR/GrokbotTestStudio"

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GrokbotTestStudio</string>
    <key>CFBundleIdentifier</key>
    <string>com.izanotchy.grokbot-test-studio</string>
    <key>CFBundleName</key>
    <string>Grokbot Test Studio</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

codesign --force --deep --sign "IzanotchyDev" "$APP_BUNDLE"

echo "==> Build succeeded: $APP_BUNDLE"
