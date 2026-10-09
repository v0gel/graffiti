#!/usr/bin/env bash
# Builds, signs and ships an update. ./release.sh "what changed"
set -euo pipefail
cd "$(dirname "$0")"
NOTES="$(printf "%b" "${1:-}")"
B="$HOME/Library/Caches/graffiti-build"
./build.sh
V=$(defaults read "$PWD/dist/Graffiti.app/Contents/Info.plist" CFBundleShortVersionString)
codesign -dr - dist/Graffiti.app 2>&1 | grep -q 'certificate leaf' || { echo "refusing: app is not signed with the Graffiti certificate"; exit 1; }
SITE="$B/site"; mkdir -p "$SITE"
ZIP="Graffiti-$V.zip"
ditto -c -k --keepParent dist/Graffiti.app "$SITE/$ZIP"
cp dist/Graffiti.dmg "$SITE/Graffiti-$V.dmg"; cp dist/Graffiti.dmg "$SITE/Graffiti.dmg"
KEY=$(security find-generic-password -s graffiti-update-key -a release -w)
cat > "$B/sign.swift" <<'SW'
import CryptoKit; import Foundation
let k = try! Curve25519.Signing.PrivateKey(rawRepresentation: Data(base64Encoded: CommandLine.arguments[1])!)
let d = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
print(try! k.signature(for: d).base64EncodedString())
SW
swiftc -O "$B/sign.swift" -o "$B/sign" 2>/dev/null
SIG=$("$B/sign" "$KEY" "$SITE/$ZIP"); unset KEY
SHA=$(shasum -a 256 "$SITE/$ZIP" | cut -d' ' -f1)
python3 - "$SITE/latest.json" "$V" "$ZIP" "$SHA" "$SIG" "$NOTES" <<'PY'
import json, sys
p, v, z, sha, sig, notes = sys.argv[1:]
json.dump({"version": v, "url": f"https://graffiti-updates.pages.dev/{z}", "sha256": sha,
           "signature": sig, "notes": notes}, open(p, "w"), indent=2)
PY
./publish-site.sh
echo "published Graffiti $V → https://graffiti-updates.pages.dev/latest.json"
