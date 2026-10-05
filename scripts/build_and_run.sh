#!/bin/bash
set -e

APP_PATH="/Users/heizaaa/Library/Developer/Xcode/DerivedData/boringNotch-fynybjceasxenmesmqcnsmlcyoaj/Build/Products/Debug/boringNotch.app"
ENTITLEMENTS="/Users/heizaaa/Library/Developer/Xcode/DerivedData/boringNotch-fynybjceasxenmesmqcnsmlcyoaj/Build/Intermediates.noindex/boringNotch.build/Debug/boringNotch.build/boringNotch.app.xcent"

echo "🔨 Building boringNotch..."
DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"
xcodebuild -project boringNotch.xcodeproj -scheme boringNotch -configuration Debug build

echo "🔏 Signing app bundle with persistent certificate IzanotchyDev..."
codesign --force --deep --sign "IzanotchyDev" --entitlements "$ENTITLEMENTS" "$APP_PATH"

echo "🔄 Thoroughly terminating previous boringNotch, cua-driver, and helpers..."
pkill -9 -f boringNotch || true
pkill -9 -f cua-driver || true
pkill -9 -f BoringNotchXPCHelper || true
rm -f /tmp/cua-izanotchy-* 2>/dev/null || true
sleep 1
open "$APP_PATH"

echo "✅ App launched with PID $(pgrep -x boringNotch)"
