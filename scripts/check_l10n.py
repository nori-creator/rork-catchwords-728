#!/usr/bin/env python3
"""CI guard: no Japanese UI text may bypass L(…), and every key must have en + zh-TW.

Exit 1 with a list of problems. Run from the repo root:  python3 scripts/check_l10n.py
"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from l10n_lib import JP_CORE, ignored, is_wrapped, key_of, line_of, scan  # noqa: E402
import re
KANA = re.compile(r"[ぁ-んァ-ヶー]")
HAN = re.compile(r"[一-鿿㐀-䶿]")

ROOT = os.path.join(os.path.dirname(__file__), "..", "ios", "CatchWords")
SKIP = {"Views/UIPreview.swift"}  # DEBUG-only fixtures for the simulator check
TABLE = os.path.join(ROOT, "Resources", "Localization", "strings.json")


def main():
    table = json.load(open(TABLE, encoding="utf-8"))
    problems, keys = [], set()
    for path in sorted(glob.glob(os.path.join(ROOT, "**", "*.swift"), recursive=True)):
        rel = os.path.relpath(path, ROOT)
        if rel in SKIP:
            continue
        src = open(path, encoding="utf-8").read()
        for start, _end, body, _multi in scan(src):
            if not JP_CORE.search(body):
                continue
            k = key_of(body)
            wrapped = is_wrapped(src, start)
            if not wrapped and ignored(src, start):
                continue  # data (server payloads, prompts, target-language words, autonyms)
            if not wrapped:
                problems.append(f"{rel}:{line_of(src, start)}: not passed through L(): \"{k}\"")
                continue
            keys.add(k)
            entry = table.get(k, {})
            for lang in ("en", "zh-TW"):
                t = entry.get(lang, "")
                if not t:
                    problems.append(f"{rel}:{line_of(src, start)}: missing {lang}: \"{k}\"")
                elif lang == "en" and (KANA.search(t) or HAN.search(t)):
                    # R1 (docs/language-rules.md): English never carries kana or Han. A learning-language
                    # sample goes in as a {n} value from NativeAPI.sample, never into the translation.
                    problems.append(f"{rel}:{line_of(src, start)}: R1 en contains Japanese/Chinese: \"{t}\"")
                elif lang == "zh-TW" and (KANA.search(t) or "・" in t):
                    # R2: Traditional Chinese never carries kana, nor the Japanese middle dot (web G3).
                    problems.append(f"{rel}:{line_of(src, start)}: R2 zh-TW contains kana: \"{t}\"")
                # placeholders must survive translation
                for i in range(1, 10):
                    ph = "{%d}" % i
                    if ph in k and ph not in t and t:
                        problems.append(f"{rel}:{line_of(src, start)}: {lang} lost {ph}: \"{t}\"")
    unused = sorted(set(table) - keys)
    if problems:
        print("\n".join(problems))
        print(f"\n{len(problems)} localization problem(s).")
        sys.exit(1)
    print(f"L10n OK: {len(keys)} keys, all with en and zh-TW." + (f" ({len(unused)} unused keys)" if unused else ""))


if __name__ == "__main__":
    main()
