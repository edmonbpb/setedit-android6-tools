#!/usr/bin/env bash
# Merge a split APK bundle into one API 23 compatible APK.
#
# usage:
#   ANDROID_BUILD_TOOLS=/path/to/build-tools/36.0.0 \
#   APKEDITOR=/path/to/APKEditor.jar \
#   KS_PASS=secret KEY_PASS=secret \
#   scripts/build.sh -i app.apks -o app-android6.apk \
#                    -k my.keystore -a mykey \
#                    [--target-sdk 22] \
#                    [--launcher-to com.example.app.MainActivity]
set -euo pipefail

BT="${ANDROID_BUILD_TOOLS:?set ANDROID_BUILD_TOOLS to a build-tools directory}"
APKEDITOR="${APKEDITOR:?set APKEDITOR to the APKEditor jar path}"
KS_PASS="${KS_PASS:?set KS_PASS}"
KEY_PASS="${KEY_PASS:-$KS_PASS}"
export KS_PASS KEY_PASS

INPUT="" OUTPUT="" KEYSTORE="" ALIAS=""
TARGET_SDK="" LAUNCHER=""

while [ $# -gt 0 ]; do
  case "$1" in
    -i) INPUT="$2"; shift 2 ;;
    -o) OUTPUT="$2"; shift 2 ;;
    -k) KEYSTORE="$2"; shift 2 ;;
    -a) ALIAS="$2"; shift 2 ;;
    --target-sdk) TARGET_SDK="$2"; shift 2 ;;
    --launcher-to) LAUNCHER="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$INPUT" ] && [ -n "$OUTPUT" ] && [ -n "$KEYSTORE" ] && [ -n "$ALIAS" ] || {
  echo "missing required arguments" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
HERE="$(cd "$(dirname "$0")" && pwd)"

tool() {
  local name="$1"
  if [ -f "$BT/$name" ]; then echo "$BT/$name"
  elif [ -f "$BT/$name.exe" ]; then echo "$BT/$name.exe"
  elif [ -f "$BT/$name.bat" ]; then echo "$BT/$name.bat"
  else echo "$BT/$name"; fi
}
ZIPALIGN="$(tool zipalign)"
APKSIGNER="$(tool apksigner)"

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys' >/dev/null 2>&1; then
      PYTHON="$candidate"
      break
    fi
  done
fi
[ -n "$PYTHON" ] || { echo "Python 3 is required" >&2; exit 1; }

echo "[1/6] merging bundle"
java -jar "$APKEDITOR" m -i "$INPUT" -o "$WORK/merged.apk" -f

SOURCE="$WORK/merged.apk"

if [ -n "$TARGET_SDK" ] || [ -n "$LAUNCHER" ]; then
  echo "[2/6] decoding manifest"
  java -jar "$APKEDITOR" d -i "$SOURCE" -o "$WORK/decoded" -f

  echo "[3/6] patching manifest"
  "$PYTHON" "$HERE/patch_manifest.py" "$WORK/decoded/AndroidManifest.xml" \
    ${TARGET_SDK:+--target-sdk "$TARGET_SDK"} \
    ${LAUNCHER:+--launcher-to "$LAUNCHER"}

  echo "[4/6] rebuilding and transplanting manifest only"
  java -jar "$APKEDITOR" b -i "$WORK/decoded" -o "$WORK/rebuilt.apk" -f
  "$PYTHON" "$HERE/swap_manifest.py" "$SOURCE" "$WORK/rebuilt.apk" "$WORK/final.apk"
  SOURCE="$WORK/final.apk"
else
  echo "[2/6] no manifest changes requested"
fi

echo "[5/6] aligning"
"$ZIPALIGN" -p -f 4 "$SOURCE" "$WORK/aligned.apk"

echo "[6/6] signing (v1 + v2 + v3, min-sdk 23)"
"$APKSIGNER" sign \
  --ks "$KEYSTORE" --ks-key-alias "$ALIAS" \
  --ks-pass "env:KS_PASS" --key-pass "env:KEY_PASS" \
  --min-sdk-version 23 \
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
  --out "$OUTPUT" "$WORK/aligned.apk"

"$HERE/verify.sh" "$OUTPUT"
