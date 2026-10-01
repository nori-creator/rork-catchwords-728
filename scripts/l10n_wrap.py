#!/usr/bin/env python3
"""One-off: wrap Japanese UI literals in L(…). Leaves switch patterns, comparisons and
string matching alone (those must stay literal), and anything marked // l10n-ignore."""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from l10n_lib import JP_CORE, ignored, is_wrapped, scan  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "ios", "CatchWords")
SKIP = {"Views/UIPreview.swift", "Utilities/L10n.swift"}
MATCHERS = ("contains(", "hasPrefix(", "hasSuffix(", "range(of:", "==", "!=", "firstIndex(of:", "replacingOccurrences(of:")

changed = 0
for path in sorted(glob.glob(os.path.join(ROOT, "**", "*.swift"), recursive=True)):
    rel = os.path.relpath(path, ROOT)
    if rel in SKIP:
        continue
    src = open(path, encoding="utf-8").read()
    edits = []
    for start, end, body, multi in scan(src):
        if multi or not JP_CORE.search(body) or is_wrapped(src, start) or ignored(src, start):
            continue
        line_start = src.rfind("\n", 0, start) + 1
        prefix = src[line_start:start]
        if re.match(r"\s*case\b", prefix) and ":" not in prefix.split("case", 1)[1].split("(")[0] and "=" not in prefix:
            continue  # switch pattern
        tail = prefix.rstrip()
        if any(tail.endswith(m) for m in MATCHERS) or re.search(r"(contains|hasPrefix|hasSuffix)\(\s*$", tail):
            continue
        if re.search(r"\bcase\s+\w+\s*=\s*$", tail):
            continue  # enum raw value
        edits.append((start, end))
    for start, end in reversed(edits):
        src = src[:start] + "L(" + src[start:end] + ")" + src[end:]
    if edits:
        open(path, "w", encoding="utf-8").write(src)
        changed += len(edits)
        print(f"{len(edits):4d} {rel}")
print("wrapped", changed)
