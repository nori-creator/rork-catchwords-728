#!/usr/bin/env python3
"""CI guard R10 (docs/language-rules.md): text written by the server (meanings, translations, notes,
reasons, journal feedback) may reach the screen only through the reader-language filter.

Allowed when the expression on the line
  - goes through ReaderLanguage.shown / ReaderLanguage.resolve / L10n.readerSafe / readable(…), or
  - reads a word that DexStore already resolved for the reader (`word…`, `.word?.…`) or a part of
    its extras (`ex.`, `chunk.`, `r.`, `m.` inside the word page / answer panel), or
  - carries `// lang-ok: <reason>` on the same line.
Anything else fails the build. When a new kind of server text is shown, add its field here.
"""
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "ios", "CatchWords")
FIELDS = r"(meaningJa|feedbackJa|questionJa|bodyJa|ja|note|exampleTranslation|scene|reason|distinction)"
USE = re.compile(r"(Text\(|accessibilityHint\(|accessibilityLabel\(|meaning:\s|label:\s)[^\n]*?\b([A-Za-z_][\w?.()]*?)\." + FIELDS + r"\b")
FILTERS = ("ReaderLanguage.", "L10n.readerSafe", "readable(")
RESOLVED = re.compile(r"(^|[^\w])(word\??|\.word\??|ex|chunk|r|m)$")
SKIP = {"Views/UIPreview.swift"}

problems = []
for path in sorted(glob.glob(os.path.join(ROOT, "Views", "**", "*.swift"), recursive=True)):
    rel = os.path.relpath(path, ROOT)
    if rel in SKIP:
        continue
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        if "lang-ok:" in line or any(f in line for f in FILTERS):
            continue
        for m in USE.finditer(line):
            base = m.group(2)
            if RESOLVED.search(base):
                continue
            problems.append(f"{rel}:{n}: R10 server text shown without the reader-language filter: {line.strip()}")
if problems:
    print("\n".join(problems))
    print(f"\n{len(problems)} problem(s). Wrap with ReaderLanguage.shown(…) / L10n.readerSafe(…), or mark `// lang-ok: why`.")
    sys.exit(1)
print("Server text OK: every server-written string on screen goes through the reader-language filter.")
