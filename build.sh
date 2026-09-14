#!/usr/bin/env bash
#
# Assembles Yank.app by hand. There is no Xcode on this machine — only the
# Command Line Tools — so the bundle is put together with mkdir and cp rather
# than by an .xcodeproj. See CLAUDE.md.
#
#   ./build.sh            debug
#   ./build.sh release    optimised
#   open build/Yank.app
#
set -euo pipefail

CONFIG="${1:-debug}"
if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
    echo "usage: $0 [debug|release]" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

APP="build/Yank.app"
CONTENTS="$APP/Contents"
BUNDLE_ID="dev.ramacharan.yank"
# Overridable from the environment so `make release VERSION=1.1` works.
VERSION="${VERSION:-1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "==> Compiling ($CONFIG)"
swift build -c "$CONFIG"
# --show-bin-path on an already-built configuration just prints the path; it is
# resolved after the build so the directory is guaranteed to exist.
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BINARY="$BIN_DIR/Yank"
if [[ ! -x "$BINARY" ]]; then
    echo "error: expected a built binary at $BINARY" >&2
    exit 1
fi

echo "==> Generating icons"
# Resources/ is gitignored — the artwork's source of truth is Tools/IconGen.swift.
swift Tools/IconGen.swift Resources > /dev/null
iconutil -c icns Resources/Yank.iconset -o Resources/Yank.icns

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BINARY" "$CONTENTS/MacOS/Yank"
cp Resources/Yank.icns "$CONTENTS/Resources/Yank.icns"
cp Resources/MenuBarIcon.png "$CONTENTS/Resources/MenuBarIcon.png"
cp Resources/MenuBarIcon@2x.png "$CONTENTS/Resources/MenuBarIcon@2x.png"

# Localisation catalogues. SwiftUI's Text looks its literals up in these; a
# missing key falls back to the literal itself.
for lproj in Localization/*.lproj; do
    [[ -d "$lproj" ]] || continue
    cp -R "$lproj" "$CONTENTS/Resources/"
done

# LSUIElement is what keeps Yank out of the Dock and out of Cmd-Tab.
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                  <string>Yank</string>
    <key>CFBundleDisplayName</key>           <string>Yank</string>
    <key>CFBundleIdentifier</key>            <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>            <string>Yank</string>
    <key>CFBundleIconFile</key>              <string>Yank</string>
    <key>CFBundlePackageType</key>           <string>APPL</string>
    <key>CFBundleShortVersionString</key>    <string>$VERSION</string>
    <key>CFBundleVersion</key>               <string>$BUILD_NUMBER</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>CFBundleDevelopmentRegion</key>     <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
$(for lproj in Localization/*.lproj; do
      [[ -d "$lproj" ]] || continue
      name="$(basename "$lproj" .lproj)"
      printf '        <string>%s</string>\n' "$name"
  done)
    </array>
    <key>LSMinimumSystemVersion</key>        <string>14.0</string>
    <key>LSUIElement</key>                   <true/>
    <key>NSHighResolutionCapable</key>       <true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP"

echo "==> Done: $APP"
