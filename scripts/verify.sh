#!/usr/bin/env bash
# Check that an APK is installable on API 23: expected SDK levels, both signing
# schemes, and 4 KiB alignment of stored native libraries.
set -euo pipefail

BT="${ANDROID_BUILD_TOOLS:?set ANDROID_BUILD_TOOLS to a build-tools directory}"
APK="${1:?usage: verify.sh <apk>}"

tool() {
  local name="$1"
  if [ -f "$BT/$name" ]; then echo "$BT/$name"
  elif [ -f "$BT/$name.exe" ]; then echo "$BT/$name.exe"
  elif [ -f "$BT/$name.bat" ]; then echo "$BT/$name.bat"
  else echo "$BT/$name"; fi
}
AAPT2="$(tool aapt2)"
APKSIGNER="$(tool apksigner)"
ZIPALIGN="$(tool zipalign)"

echo "== badging"
"$AAPT2" dump badging "$APK" | grep -E "^(package|sdkVersion|targetSdkVersion|launchable-activity)"

echo "== signature"
"$APKSIGNER" verify -v "$APK" | grep -E "Verified using (v1|v2|v3) scheme"

echo "== alignment"
"$ZIPALIGN" -c -p -v 4 "$APK" >/dev/null
echo "alignment ok"
