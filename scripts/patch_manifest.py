#!/usr/bin/env python3
"""Patch a decoded AndroidManifest.xml produced by APKEditor.

Two edits, both opt-in:
  --target-sdk N       rewrite android:targetSdkVersion
  --launcher-to FQCN   move the MAIN/LAUNCHER intent-filter to another activity

The script fails loudly (non-zero exit) instead of guessing when the manifest
does not look the way the edit expects.
"""
import argparse
import re
import sys


def fail(msg):
    sys.stderr.write("patch_manifest: " + msg + "\n")
    sys.exit(2)


def set_target_sdk(text, value):
    pattern = re.compile(r'android:targetSdkVersion="(\d+)"')
    found = pattern.findall(text)
    if len(found) != 1:
        fail("expected exactly one android:targetSdkVersion, found %d" % len(found))
    return pattern.sub('android:targetSdkVersion="%d"' % value, text)


def find_launcher_filter(text):
    pattern = re.compile(
        r'[ \t]*<intent-filter>\s*'
        r'<action android:name="android\.intent\.action\.MAIN" />\s*'
        r'<category android:name="android\.intent\.category\.LAUNCHER" />\s*'
        r'</intent-filter>\s*'
    )
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        fail("expected exactly one MAIN/LAUNCHER intent-filter, found %d" % len(matches))
    return matches[0]


def activity_bounds(text, fqcn):
    marker = 'android:name="%s"' % fqcn
    hits = [m.start() for m in re.finditer(re.escape(marker), text)]
    if len(hits) != 1:
        fail("expected exactly one declaration of %s, found %d" % (fqcn, len(hits)))

    start = text.rfind("<activity", 0, hits[0])
    if start == -1:
        fail("could not find the <activity> element for %s" % fqcn)

    self_closing = text.find("/>", start)
    closing = text.find("</activity>", start)
    if self_closing != -1 and (closing == -1 or self_closing < closing):
        return start, self_closing + 2, True
    if closing == -1:
        fail("could not find the end of the <activity> element for %s" % fqcn)
    return start, closing + len("</activity>"), False


def move_launcher(text, fqcn):
    match = find_launcher_filter(text)
    filter_text = (
        "\n      <intent-filter>\n"
        '        <action android:name="android.intent.action.MAIN" />\n'
        '        <category android:name="android.intent.category.LAUNCHER" />\n'
        "      </intent-filter>"
    )
    text = text[: match.start()] + text[match.end():]

    start, end, self_closing = activity_bounds(text, fqcn)
    if self_closing:
        element = text[start:end]
        replacement = element[:-2].rstrip() + ">" + filter_text + "\n    </activity>"
        return text[:start] + replacement + text[end:]

    closing = text.rfind("</activity>", start, end)
    return text[:closing] + filter_text + text[closing:]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest")
    parser.add_argument("--target-sdk", type=int)
    parser.add_argument("--launcher-to")
    args = parser.parse_args()

    with open(args.manifest, "r", encoding="utf-8") as handle:
        text = handle.read()

    if args.target_sdk is not None:
        text = set_target_sdk(text, args.target_sdk)
    if args.launcher_to:
        text = move_launcher(text, args.launcher_to)

    with open(args.manifest, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("patched", args.manifest)


if __name__ == "__main__":
    main()
