#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
CORE="$ROOT/Packages/TracalCore"

cd "$CORE"

if swift test >/dev/null 2>&1; then
  swift test
  exit 0
fi

# The macOS 27 Command Line Tools currently ship swift-package with incomplete
# runtime search paths when full Xcode is absent. Run an isolated mirror from
# /tmp so DYLD paths are honored; nothing under CommandLineTools is modified.
DEVELOPER="$(xcode-select -p)"
MIRROR="$(mktemp -d /tmp/tracal-clt.XXXXXX)"
trap 'rm -rf "$MIRROR"' EXIT

mkdir -p "$MIRROR/usr/bin"
cp "$DEVELOPER/usr/bin/swift-frontend" "$MIRROR/usr/bin/swift"
cp "$DEVELOPER/usr/bin/swift-frontend" "$MIRROR/usr/bin/swiftc"
cp "$DEVELOPER/usr/bin/swift-driver" "$MIRROR/usr/bin/swift-driver"
cp "$DEVELOPER/usr/bin/swift-package" "$MIRROR/usr/bin/swift-package"
cp "$DEVELOPER/usr/bin/swift-plugin-server" "$MIRROR/usr/bin/swift-plugin-server"
ln -s swift-package "$MIRROR/usr/bin/swift-test"
ln -s "$DEVELOPER/usr/lib" "$MIRROR/usr/lib"
ln -s "$DEVELOPER/usr/libexec" "$MIRROR/usr/libexec"
ln -s "$DEVELOPER/usr/local" "$MIRROR/usr/local"
ln -s "$DEVELOPER/Library" "$MIRROR/Library"
ln -s "$DEVELOPER/SDKs" "$MIRROR/SDKs"

PM="$DEVELOPER/usr/lib/swift/pm"
SERVICE_FRAMEWORKS="$PM/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildService.bundle/Contents/Frameworks"
SYSTEM_FRAMEWORKS="$PM/SwiftBuild.framework/Versions/A/PlugIns/SWBBuildSystem.bundle/Contents/Frameworks"
TEST_FRAMEWORKS="$DEVELOPER/Library/Developer/Frameworks"
TEST_LIBRARIES="$DEVELOPER/Library/Developer/usr/lib"

DYLD_FRAMEWORK_PATH="$TEST_FRAMEWORKS:$PM:$PM/llbuild:$SERVICE_FRAMEWORKS:$SYSTEM_FRAMEWORKS" \
DYLD_LIBRARY_PATH="$TEST_LIBRARIES:$DEVELOPER/usr/lib:$PM/llbuild:$PM" \
  "$MIRROR/usr/bin/swift" test

