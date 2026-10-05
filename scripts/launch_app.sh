#!/bin/bash
set -e

APP_PATH="/Users/heizaaa/Library/Developer/Xcode/DerivedData/boringNotch-fynybjceasxenmesmqcnsmlcyoaj/Build/Products/Debug/boringNotch.app"
ENTITLEMENTS="/Users/heizaaa/Library/Developer/Xcode/DerivedData/boringNotch-fynybjceasxenmesmqcnsmlcyoaj/Build/Intermediates.noindex/boringNotch.build/Debug/boringNotch.build/boringNotch.app.xcent"

echo "Signing app bundle..."
codesign --force --deep --sign "IzanotchyDev" --entitlements "$ENTITLEMENTS" "$APP_PATH"

echo "Terminating old processes..."
pkill -9 -f boringNotch 2>/dev/null || true
pkill -9 -f cua-driver 2>/dev/null || true
pkill -9 -f BoringNotchXPCHelper 2>/dev/null || true
rm -f /tmp/cua-izanotchy-* 2>/dev/null || true
sleep 1

echo "Opening app..."
open "$APP_PATH"
sleep 1

PID=$(pgrep -x boringNotch || true)
echo "LAUNCH_SUCCESS_PID: $PID"
