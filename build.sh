#!/usr/bin/env bash
# Builds the app and the installer, for Apple silicon and Intel.
set -euo pipefail
cd "$(dirname "$0")"
B="$HOME/Library/Caches/graffiti-build"
VERSION="${VERSION:-0.2.7}"
swift build -c release --scratch-path "$B" --triple arm64-apple-macosx13.0
swift build -c release --scratch-path "$B" --triple x86_64-apple-macosx13.0
mkdir -p "$B/universal"
lipo -create -output "$B/universal/Graffiti" \
  "$B/arm64-apple-macosx/release/Graffiti" "$B/x86_64-apple-macosx/release/Graffiti"
APP=dist/Graffiti.app
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$B/universal/Graffiti" "$APP/Contents/MacOS/Graffiti"
cp Resources/* "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Graffiti</string>
  <key>CFBundleDisplayName</key><string>Graffiti</string>
  <key>CFBundleIdentifier</key><string>com.superboss.graffiti</string>
  <key>CFBundleExecutable</key><string>Graffiti</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleIconFile</key><string>Graffiti</string>
  <key>NSHumanReadableCopyright</key><string>Scott Vogel</string>
</dict></plist>
PLIST
if security find-identity -p codesigning 2>/dev/null | grep -q "Graffiti Local Signing"; then
  codesign --force --sign "Graffiti Local Signing" "$APP"
else
  echo "note: no Graffiti Local Signing certificate here, signing ad-hoc"; codesign --force --sign - "$APP"
fi
STAGE=$(mktemp -d); RW="$(mktemp -d)/rw.dmg"
cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/.background" && cp assets/dmg/background.tiff "$STAGE/.background/background.tiff"
ALLOW="$STAGE/Allow Graffiti.url"
printf '[InternetShortcut]\nURL=x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Security\n' > "$ALLOW"
swiftc -O assets/set-icon.swift -o "$B/set-icon" 2>/dev/null && "$B/set-icon" "/System/Applications/System Settings.app/Contents/Resources/SystemSettings.icns" "$ALLOW" || true
/Library/Developer/CommandLineTools/usr/bin/SetFile -a E "$ALLOW" || true
hdiutil create -quiet -srcfolder "$STAGE" -volname "Graffiti $VERSION" -fs HFS+ -format UDRW -layout NONE -ov "$RW"
for v in /Volumes/Graffiti*; do [ -d "$v" ] && hdiutil detach -quiet "$v" || true; done
MNT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')
osascript <<OSA || echo "  (Finder layout skipped: allow this terminal to control Finder, then rebuild)"
tell application "Finder"
  tell disk "$(basename "$MNT")"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 840, 702}
    set o to icon view options of container window
    set arrangement of o to not arranged
    set icon size of o to 112
    set text size of o to 13
    set background picture of o to file ".background:background.tiff"
    set position of item "Graffiti.app" of container window to {170, 165}
    set position of item "Applications" of container window to {470, 165}
    set position of item "Allow Graffiti.url" of container window to {500, 370}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
cp Resources/Graffiti.icns "$MNT/.VolumeIcon.icns"
/Library/Developer/CommandLineTools/usr/bin/SetFile -a C "$MNT" || true
sync; hdiutil detach -quiet "$MNT"
python3 - "$RW" <<'PY'
import sys, struct
f = open(sys.argv[1], "r+b"); f.seek(1024)
assert f.read(2) in (b"H+", b"HX"), "not an HFS+ volume header"
f.seek(1024 + 80 + 8); f.write(struct.pack(">I", 2)); f.close()
PY
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -ov -o dist/Graffiti.dmg
rm -rf "$STAGE" "$(dirname "$RW")"
"$B/set-icon" Resources/Graffiti.icns dist/Graffiti.dmg
echo "built: $(du -sh "$APP" | cut -f1) app, $(du -sh dist/Graffiti.dmg | cut -f1) dmg → $(pwd)/dist/Graffiti.dmg"
