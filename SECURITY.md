# Security policy

This repository contains build scripts only. It ships no APK.

## What the scripts can do

Re-signing an APK changes its signing identity. A build produced here cannot be
updated from an app store, and the previous copy of the app must be uninstalled
first. Lowering `targetSdkVersion` to 22 disables the runtime permission model
on Android 6 and blocks installation on Android 14+.

`Settings.Secure` / `Settings.Global` writes require a privileged helper. Grant
`android.permission.WRITE_SECURE_SETTINGS` only to the helper package you
intend to use, and only on a device you own.

## Reporting

If you find a problem in the scripts, open an issue. Do not paste keystore
material, passwords, device identifiers or signing tokens into issues.
