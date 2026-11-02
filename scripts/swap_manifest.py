#!/usr/bin/env python3
"""Copy every entry of a base APK, replacing only AndroidManifest.xml.

Why: rebuilding an APK with APKEditor re-encodes resources, which can silently
break animated vector drawables. Rebuilding only to obtain a patched manifest
and then transplanting that single file keeps every resource, dex and native
library bit-identical to the merged base.
"""
import sys
import zipfile


def main():
    if len(sys.argv) != 4:
        sys.stderr.write("usage: swap_manifest.py <base.apk> <patched.apk> <out.apk>\n")
        return 2

    base_path, patched_path, out_path = sys.argv[1:4]
    with zipfile.ZipFile(patched_path) as patched:
        manifest = patched.read("AndroidManifest.xml")

    with zipfile.ZipFile(base_path) as base, zipfile.ZipFile(out_path, "w") as out:
        for item in base.infolist():
            data = base.read(item.filename)
            if item.filename == "AndroidManifest.xml":
                data = manifest
            out.writestr(item, data)

    print("wrote", out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
