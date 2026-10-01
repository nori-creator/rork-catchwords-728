"""Shared Swift string-literal scanner for the localization tools.

Finds every string literal in a Swift file (skipping comments), tells whether it contains
Japanese, whether it is already wrapped as L("…"), and turns it into the table key
(interpolations become {1}, {2} … — the same rule as LKey in Utilities/L10n.swift).
"""
import re

JP = re.compile(r"[ぁ-んァ-ヶ一-龯々ー〜、。「」（）！？]")
JP_CORE = re.compile(r"[ぁ-んァ-ヶ一-龯々]")


def scan(src):
    """Yield (start, end, body, is_multiline) for each string literal outside comments.
    start/end are offsets of the opening and closing quote run (end exclusive)."""
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c == '#':
            # raw strings  #"…"#  — rare here; skip them whole
            m = re.match(r'(#+)"', src[i:])
            if m:
                hashes = m.group(1)
                close = '"' + hashes
                j = src.find(close, i + len(m.group(0)))
                i = n if j < 0 else j + len(close)
                continue
        if c == '"':
            multi = src.startswith('"""', i)
            q = 3 if multi else 1
            j = i + q
            depth = 0
            while j < n:
                if src[j] == "\\" and j + 1 < n:
                    if src[j + 1] == "(":
                        # interpolation: skip balanced parens, honoring nested strings
                        k = j + 2
                        d = 1
                        while k < n and d > 0:
                            if src[k] == "(":
                                d += 1
                            elif src[k] == ")":
                                d -= 1
                            elif src[k] == '"':
                                k2 = k + 1
                                while k2 < n and src[k2] != '"':
                                    k2 += 2 if src[k2] == "\\" else 1
                                k = k2
                            k += 1
                        j = k
                        continue
                    j += 2
                    continue
                if multi and src.startswith('"""', j):
                    break
                if not multi and src[j] == '"':
                    break
                if not multi and src[j] == "\n":
                    break
                j += 1
            end = j + q
            yield i, end, src[i + q:j], multi
            i = end
            continue
        i += 1


def key_of(body):
    """Swift literal body → runtime key with {n} placeholders."""
    out, i, n, k = [], 0, len(body), 0
    while i < n:
        ch = body[i]
        if ch == "\\" and i + 1 < n:
            nx = body[i + 1]
            if nx == "(":
                d, j = 1, i + 2
                while j < n and d > 0:
                    if body[j] == "(":
                        d += 1
                    elif body[j] == ")":
                        d -= 1
                    j += 1
                k += 1
                out.append("{%d}" % k)
                i = j
                continue
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": "\0"}.get(nx, nx))
            i += 2
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def is_wrapped(src, start):
    before = src[max(0, start - 12):start].rstrip()
    return before.endswith("L(") or before.endswith("L (")


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def ignored(src, start):
    """A literal on a line ending with `// l10n-ignore` is data, not UI (server payloads, prompts)."""
    line_start = src.rfind("\n", 0, start) + 1
    line_end = src.find("\n", start)
    line = src[line_start: line_end if line_end >= 0 else len(src)]
    prev = src[src.rfind("\n", 0, max(0, line_start - 1)) + 1: max(0, line_start - 1)]
    # same line, or a `// l10n-ignore` comment line right above (for multi-line literals)
    return "l10n-ignore" in line or prev.strip().startswith("// l10n-ignore")
