#!/usr/bin/env python3
"""Add translations to the strings table: python3 scripts/add_strings.py new.json (a {ja: {en, zh-TW}} map)."""
import json, sys
P = "ios/CatchWords/Resources/Localization/strings.json"
raw = open(P, encoding="utf-8").read()
d = json.loads(raw)
was_sorted = list(d) == sorted(d)
new = json.load(open(sys.argv[1], encoding="utf-8"))
for k, v in new.items():
    assert set(v) == {"en", "zh-TW"}, k
    d[k] = v
if was_sorted:
    d = dict(sorted(d.items()))
indent = 2 if raw.startswith("{\n  \"") else (1 if raw.startswith("{\n \"") else None)
open(P, "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False, indent=indent) + ("\n" if raw.endswith("\n") else ""))
print(f"{len(new)} added, {len(d)} keys")
