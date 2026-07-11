#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"

cd "$ROOT"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
  if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  elif [[ -d "$HOME/Downloads/Xcode-beta.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="$HOME/Downloads/Xcode-beta.app/Contents/Developer"
  fi
fi

plutil -lint Config/Info.plist Tracal/Resources/PrivacyInfo.xcprivacy

scripts/test_core.sh

xcodegen generate

if xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  xcodebuild \
    -project Tracal.xcodeproj \
    -scheme Tracal \
    -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  print "Skipped iOS build: install and select full Xcode to provide the iPhoneOS SDK."
fi
