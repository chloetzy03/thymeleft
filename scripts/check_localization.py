#!/usr/bin/env python3
"""Checks that every text in the app has a Chinese translation.

How to use (after a normal build):
    python3 scripts/check_localization.py /path/to/DerivedData

It reads the texts the Swift compiler found (the .stringsdata files from the last build) and compares
them with `thyme left/Localizable.xcstrings`. It reports:
  - texts with no Chinese translation yet (add them to the catalog),
  - translations nobody uses any more,
  - translations whose %@ / %lld placeholders don't match the English text.
Exit code 0 = all good.
"""
import glob, json, re, sys, pathlib

derived = sys.argv[1] if len(sys.argv) > 1 else "/tmp/thymeleft-dd"
root = pathlib.Path(__file__).resolve().parent.parent
catalog = json.load(open(root / "thyme left" / "Localizable.xcstrings"))["strings"]

found = set()
pattern = f"{derived}/Build/Intermediates.noindex/thyme left.build/*/thyme left.build/Objects-normal/*/*.stringsdata"
for path in glob.glob(pattern):
    for entries in json.load(open(path)).get("tables", {}).get("Localizable", []) and [json.load(open(path))["tables"]["Localizable"]]:
        found.update(e["key"] for e in entries)

spec = re.compile(r"%(?:\d+\$)?(lld|lf|@)")
problems = 0
for key in sorted(found):
    entry = catalog.get(key)
    value = entry and entry.get("localizations", {}).get("zh-Hans", {}).get("stringUnit", {}).get("value")
    if not value:
        print("MISSING Chinese:", repr(key)); problems += 1; continue
    if sorted(m.group(1) for m in spec.finditer(key)) != sorted(m.group(1) for m in spec.finditer(value)):
        print("PLACEHOLDERS differ:", repr(key)); problems += 1
for key in sorted(set(catalog) - found):
    print("UNUSED translation:", repr(key)); problems += 1
print(f"{len(found)} texts in the app, {problems} problem(s)")
sys.exit(1 if problems else 0)
