#!/bin/sh
# App Store screenshots in Polish and English, in the native resolution of the chosen simulator:
#   "iPhone 17 Pro Max" -> 6.9" slot, 1320×2868   (default)
#   "iPhone 17 Pro"     -> 6.3" slot, 1206×2622
# Builds the Debug app, launches it in the Simulator in demo mode (-demoScreen …, sample data
# in memory, no Bluetooth) and saves them to release_apple_store/screenshots/<WIDTHxHEIGHT>/<lang>/.
#
# Usage: release_apple_store/make_screenshots.sh ["iPhone 17 Pro Max" | "iPhone 17 Pro"]
# Requires: Xcode, a simulator with that name, include/family_key.h is NOT needed.
set -eu
cd "$(dirname "$0")/.."

DEVICE=${1:-"iPhone 17 Pro Max"}
BUNDLE=$(xcodebuild -project ios/FamilyTodo.xcodeproj -scheme FamilyTodo -showBuildSettings 2>/dev/null \
         | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER =/ {print $2; exit}')
DERIVED=${TMPDIR:-/tmp}/familytodo-screenshots
ROOT=release_apple_store/screenshots
SCREENS="list editor history settings setup"

UDID=$(xcrun simctl list devices available | grep -F "    $DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "Simulator '$DEVICE' not found" >&2; exit 1; }

xcodebuild -project ios/FamilyTodo.xcodeproj -scheme FamilyTodo -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build -quiet
APP="$DERIVED/Build/Products/Debug-iphonesimulator/FamilyTodo.app"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$UDID" "$APP"

# Output folder named after the device's native screenshot size.
probe=$DERIVED/probe.png
xcrun simctl io "$UDID" screenshot --type=png "$probe" >/dev/null 2>&1
OUT=$ROOT/$(sips -g pixelWidth -g pixelHeight "$probe" | awk '/pixelWidth/ {w=$2} /pixelHeight/ {h=$2} END {print w "x" h}')

for lang in pl en; do
  case $lang in pl) locale=pl_PL ;; en) locale=en_US ;; esac
  mkdir -p "$OUT/$lang"
  n=1
  for screen in $SCREENS; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" -demoScreen "$screen" \
      -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null
    sleep 4
    file="$OUT/$lang/0${n}_${screen}.png"
    xcrun simctl io "$UDID" screenshot --type=png "$file" >/dev/null 2>&1
    echo "$file"
    n=$((n + 1))
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl status_bar "$UDID" clear
