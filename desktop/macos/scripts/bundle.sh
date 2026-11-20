#!/bin/zsh
# Builds Hackatime Desktop.app. Without SIGN_IDENTITY it is ad-hoc signed:
# everything works except App Attest, and a software key is used if the
# Secure Enclave refuses an unsigned process. With a Developer ID identity,
# TEAM_ID and a provisioning profile carrying App Attest (PROFILE), it is
# signed with entitlements and hardened runtime, ready to notarise.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${CONFIG:-release}
swift build -c "$CONFIG" --arch arm64 --arch x86_64 2>/dev/null || swift build -c "$CONFIG"
BIN=$(swift build -c "$CONFIG" --show-bin-path)
APP=build/"Hackatime Desktop.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/HackatimeDesktop" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  [[ -n "${PROFILE:-}" ]] && cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
  sed "s/\$(TEAM_ID)/${TEAM_ID:?set TEAM_ID}/" Resources/HackatimeDesktop.entitlements > build/entitlements.plist
  codesign --force --options runtime --timestamp --entitlements build/entitlements.plist --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --verbose=2 "$APP"
echo "$APP"
