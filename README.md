# SetEdit on Android 6 — repackaging toolkit

Tools and notes for turning a modern **split APK bundle (`.apks`)** of a settings-editor app into **one APK that installs and runs on Android 6.0 (API 23)**, plus the extra steps that make it *usable* without a PC.

> **This repository contains no application binaries.** The editor APK is third-party software and is **not** redistributed here. You must supply your own bundle. This project is not affiliated with, endorsed by, or supported by the app's author.

## What it solves

A `.apks` bundle from an APK mirror is not installable by tapping, and it cannot be installed on Android 6 without `adb install-multiple`. Installing `base.apk` alone breaks at runtime because density and language resources live in the split APKs.

The toolkit:

1. **Merges** `base.apk` + `config.*.apk` into one APK (APKEditor).
2. **Optionally lowers `targetSdkVersion` to 22**, which makes Android 6 auto-grant `WRITE_SETTINGS` at install (no manual "Modify system settings" toggle).
3. **Optionally moves the launcher intent-filter to the main activity**, so a first run does not stop on an onboarding screen whose "Next" button requires an adb-granted permission.
4. **Aligns and signs** with v1 + v2 + v3 so API 23 accepts the package.
5. **Verifies** the result (`aapt2`, `apksigner`, `zipalign`).

## Requirements

| Tool | Notes |
|---|---|
| JDK 17 | runs APKEditor |
| Android SDK build-tools | `zipalign`, `apksigner`, `aapt2` |
| [APKEditor](https://github.com/REAndroid/APKEditor) | Apache-2.0, downloaded separately |
| Python 3 | only for the manifest helpers |

## Quick start

```bash
# 1. merge the bundle into one APK
java -jar APKEditor.jar m -i app.apks -o merged.apk

# 2. decode, patch, rebuild, then move ONLY the manifest back (see below)
java -jar APKEditor.jar d -i merged.apk -o decoded
python3 scripts/patch_manifest.py decoded/AndroidManifest.xml \
        --target-sdk 22 \
        --launcher-to com.example.app.MainActivity
java -jar APKEditor.jar b -i decoded -o rebuilt.apk
python3 scripts/swap_manifest.py merged.apk rebuilt.apk merged-fixed.apk

# 3. align + sign for API 23
zipalign -p -f 4 merged-fixed.apk aligned.apk
apksigner sign --ks my.keystore --ks-key-alias mykey \
  --min-sdk-version 23 \
  --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true \
  --out app-android6.apk aligned.apk

# 4. verify
scripts/verify.sh app-android6.apk
```

`scripts/build.sh` chains all of the above.

## The step everyone gets wrong

A full APKEditor **decode → build** round-trip re-encodes resources. In the build this project was tested on, that round-trip broke **animated vector drawables** (the toolbar gear icon and the walkthrough illustration rendered blank), while every resource ID and file path stayed identical.

The fix that was verified on-device: rebuild only to obtain a patched `AndroidManifest.xml`, then **copy that one file into the original merged APK** and leave every resource untouched (`scripts/swap_manifest.py`). Resources, dex and native libraries then stay bit-identical to the merged output.

## What was verified on Android 6.0 (API 23, x86_64 emulator)

| Check | Result |
|---|---|
| `adb install` of the single merged APK | pass |
| Launch from the launcher icon | pass |
| `WRITE_SETTINGS` granted at install with `targetSdkVersion 22` | pass (`granted=true`) |
| Edit a `Settings.System` value and re-read it | pass (value persisted) |
| Search, details screen, save/cancel | pass |
| Animated icons and the walkthrough illustration | pass (after the manifest-swap fix) |
| `Settings.Secure` write with the helper package + `pm grant` | pass |
| `Settings.Secure` write **without** the helper | fails with `SecurityException` (expected) |

## Known limits

- **`Settings.Secure` / `Settings.Global` writes need a privileged helper.** The helper (`com.netvor.settings.database.provider`, Apache-2.0, published on F-Droid/IzzyOnDroid) must be installed and granted `android.permission.WRITE_SECURE_SETTINGS` once:
  ```bash
  adb shell pm grant com.netvor.settings.database.provider android.permission.WRITE_SECURE_SETTINGS
  ```
  Without adb (or root) this is not possible.
- **`targetSdkVersion 22` blocks installation on Android 14+** (`INSTALL_FAILED_DEPRECATED_SDK_VERSION`), unless installed with `adb install --bypass-low-target-sdk-block`. Keep a normal `targetSdk` build for newer devices.
- **Signature changes.** Any re-signed build has a different signing identity: the previous copy must be uninstalled, and store updates no longer apply.
- **Language keys such as `white_languages`** usually live in the `System` table and are editable through the app; whether the OS actually switches language depends on the ROM and usually needs a reboot.

## Repository layout

```
scripts/   build, manifest patching, verification
docs/      behaviour notes, test log, Persian guide
```

## Legal

This repository ships **no APK** and no decompiled or modified code from the application. It documents an interoperability workflow for devices you own, on a bundle you obtained yourself. The application, its name and its assets belong to their respective owners. `Settings Database Provider` and `APKEditor` are Apache-2.0; see `NOTICE`.

**Responsibility for how you use these scripts and for any device you modify is yours.** No warranty of any kind. Changing system settings can break a device; back up first.

## License

MIT for the scripts and documentation in this repository — see `LICENSE`.
