# Verification log

Environment: Android 6.0 (API 23), `google_apis` x86_64 emulator, JDK 17,
Android build-tools 36.0.0. Source bundle: a split `.apks` of the settings
editor (base + density + locale splits), `minSdkVersion 23`, `compileSdk 36`.

## Build

| Step | Result |
|---|---|
| `APKEditor m` merge of base + 14 config splits | 1714 entries, ~12 MB |
| Manifest patched (`targetSdkVersion` 36 → 22, launcher → main activity) | pass |
| `apksigner` v1 + v2 + v3, `--min-sdk-version 23` | pass |
| `zipalign -c -p 4` | pass |
| Native libraries stored uncompressed, page aligned | pass |

## Runtime

| Check | Evidence |
|---|---|
| `adb install -r` on API 23 | `Success` |
| App opens from the launcher icon | resumed activity = main activity |
| `WRITE_SETTINGS` granted without user action | `dumpsys package`: `granted=true` |
| Write `Settings.System` value, then read it back | `settings get system accelerometer_rotation` changed 1 → 0 |
| Search screen, details screen, save | pass, no `FATAL EXCEPTION` in logcat |
| Helper package + `pm grant WRITE_SECURE_SETTINGS` | `granted=true` |
| Write `Settings.Secure` value through the helper | `settings get secure mock_location` changed 0 → 1 |
| Write `Settings.Secure` without the helper | `SecurityException: ... requires:android.permission.WRITE_SECURE_SETTINGS` (expected) |
| Animated toolbar icon and walkthrough illustration after manifest transplant | render correctly |

## Resource regression that was caught

A full APKEditor decode → build round-trip produced an APK whose animated
vector drawables rendered blank (toolbar gear, walkthrough illustration), while
all 5605 resource IDs and all 1530 resource paths were unchanged. Restoring the
resource files from the merged APK fixed the rendering; the shipped approach
therefore transplants only `AndroidManifest.xml` instead of rebuilding
resources.

## Notes

- `targetSdkVersion 22` is what makes `WRITE_SETTINGS` install-time. On API 23
  that is the legacy permission path; it does not exist for `targetSdk >= 23`.
- `Settings.Secure` also requires the modern settings provider restriction to
  be bypassed on some ROMs; the helper does that by holding the privileged
  permission.
