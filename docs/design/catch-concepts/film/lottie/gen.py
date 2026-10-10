"""Hand-authored Lottie animations for the catch moment (usable with lottie-ios in the app as-is).
burst.json   - celebration burst: shockwave ring, 12 shooting rays, 10 four-point sparkles, 14 confetti dots
twinkle.json - three small sparkles popping (slot / tab arrival)
ripple.json  - double ring ripple (tab arrival)
"""
import json, math, random
random.seed(7)
FPS = 60
def hexc(h): h = h.lstrip("#"); return [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)] + [1]
WHITE, GOLD, BLUE, CYAN, PINK = hexc("FFFFFF"), hexc("F4B93C"), hexc("2A9BFF"), hexc("64E0FF"), hexc("FF7AB6")
def st(v): return {"a": 0, "k": v}
def kf(frames, ease_out=(0.2, 1), ease_in=(0.33, 0)):
    """frames: [(t, value), ...] value scalar or list"""
    out = []
    for i, (t, v) in enumerate(frames):
        v = v if isinstance(v, list) else [v]
        k = {"t": t, "s": v}
        if i < len(frames) - 1:
            n = len(v)
            k["o"] = {"x": [ease_in[0]] * n, "y": [ease_in[1]] * n}
            k["i"] = {"x": [ease_out[0]] * n, "y": [ease_out[1]] * n}
        out.append(k)
    return {"a": 1, "k": out}
def tr(p=(0, 0), s=(100, 100), r=0, o=100):
    return {"ty": "tr", "p": p if isinstance(p, dict) else st(list(p)), "a": st([0, 0]), "s": s if isinstance(s, dict) else st(list(s)),
            "r": r if isinstance(r, dict) else st(r), "o": o if isinstance(o, dict) else st(o), "sk": st(0), "sa": st(0)}
def layer(ind, nm, shapes, W, H, op, ks=None):
    k = {"o": st(100), "r": st(0), "p": st([W / 2, H / 2, 0]), "a": st([0, 0, 0]), "s": st([100, 100, 100])}
    if ks: k.update(ks)
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": nm, "sr": 1, "ks": k, "ao": 0, "shapes": shapes, "ip": 0, "op": op, "st": 0, "bm": 0}
def path(vs, closed=True):
    z = [[0, 0]] * len(vs)
    return {"ty": "sh", "ks": st({"i": z, "o": z, "v": vs, "c": closed})}
def star4(R, k=0.2):
    a = R * k
    return path([[0, -R], [a, -a], [R, 0], [a, a], [0, R], [-a, a], [-R, 0], [-a, -a]])
def comp(nm, W, H, op, layers):
    return {"v": "5.7.4", "fr": FPS, "ip": 0, "op": op, "w": W, "h": H, "nm": nm, "ddd": 0, "assets": [], "layers": layers}

def burst():
    W = H = 800; op = 54; L = []
    # shockwave ring (two strokes: soft wide + crisp)
    for i, (wd, col, o0) in enumerate([(26, CYAN, 55), (6, WHITE, 100)]):
        L.append(layer(len(L) + 1, f"ring{i}", [{"ty": "gr", "it": [
            {"ty": "el", "p": st([0, 0]), "s": kf([(0, [60, 60]), (26, [640, 640])], ease_out=(0.15, 1), ease_in=(0.1, 0.6)), "d": 1},
            {"ty": "st", "c": st(col), "o": kf([(0, o0), (8, o0), (26, 0)]), "w": kf([(0, wd), (26, 1)]), "lc": 2, "lj": 2},
            tr()]}], W, H, op))
    # rays
    cols = [WHITE, GOLD, CYAN, WHITE, PINK, GOLD]
    for i in range(12):
        a = i / 12 * math.tau + (0.13 if i % 2 else 0)
        r0, r1 = 70, 250 + (60 if i % 2 == 0 else 0)
        p0 = [math.cos(a) * r0, math.sin(a) * r0]; p1 = [math.cos(a) * r1, math.sin(a) * r1]
        d = 2 if i % 2 else 0
        L.append(layer(len(L) + 1, f"ray{i}", [{"ty": "gr", "it": [
            path([p0, p1], closed=False),
            {"ty": "tm", "s": kf([(3 + d, 0), (22 + d, 100)], ease_out=(0.2, 1), ease_in=(0.5, 0)), "e": kf([(0 + d, 0), (14 + d, 100)], ease_out=(0.15, 1), ease_in=(0.3, 0)), "o": st(0), "m": 1},
            {"ty": "st", "c": st(cols[i % len(cols)]), "o": st(100), "w": kf([(d, 16 if i % 2 == 0 else 10), (22 + d, 3)]), "lc": 2, "lj": 2},
            tr()]}], W, H, op))
    # sparkles
    for i in range(10):
        a = random.random() * math.tau; r = random.uniform(150, 320)
        x, y = math.cos(a) * r, math.sin(a) * r; R = random.uniform(16, 34); t0 = random.randint(6, 18)
        col = [WHITE, GOLD, CYAN][i % 3]
        L.append(layer(len(L) + 1, f"spark{i}", [{"ty": "gr", "it": [
            star4(R), {"ty": "fl", "c": st(col), "o": st(100), "r": 1},
            tr(p=kf([(t0, [x * 0.7, y * 0.7]), (t0 + 30, [x, y])], ease_out=(0.2, 1), ease_in=(0.1, 0.8)),
               s=kf([(t0, [0, 0]), (t0 + 8, [115, 115]), (t0 + 14, [90, 90]), (t0 + 30, [0, 0])]),
               r=kf([(t0, -30), (t0 + 30, 60)]))]}], W, H, op))
    # confetti dots
    for i in range(14):
        a = random.random() * math.tau; r = random.uniform(200, 360)
        x, y = math.cos(a) * r, math.sin(a) * r; t0 = random.randint(2, 10); sz = random.uniform(10, 18)
        col = [GOLD, BLUE, PINK, CYAN, WHITE][i % 5]
        L.append(layer(len(L) + 1, f"dot{i}", [{"ty": "gr", "it": [
            {"ty": "el", "p": st([0, 0]), "s": st([sz, sz]), "d": 1}, {"ty": "fl", "c": st(col), "o": st(100), "r": 1},
            tr(p=kf([(t0, [x * 0.25, y * 0.25]), (t0 + 34, [x, y + 60])], ease_out=(0.2, 1), ease_in=(0.05, 0.7)),
               o=kf([(t0, 100), (t0 + 24, 100), (t0 + 36, 0)]))]}], W, H, op))
    return comp("CatchBurst", W, H, op, L)

def twinkle():
    W = H = 300; op = 40; L = []
    for i, (x, y, R, t0, col) in enumerate([(-60, -40, 26, 0, WHITE), (55, -60, 18, 5, GOLD), (40, 55, 22, 9, CYAN)]):
        L.append(layer(i + 1, f"tw{i}", [{"ty": "gr", "it": [
            star4(R, 0.16), {"ty": "fl", "c": st(col), "o": st(100), "r": 1},
            tr(p=st([x, y]), s=kf([(t0, [0, 0]), (t0 + 9, [120, 120]), (t0 + 16, [85, 85]), (t0 + 28, [0, 0])]), r=kf([(t0, 0), (t0 + 28, 90)]))]}], W, H, op))
    return comp("Twinkle", W, H, op, L)

def ripple():
    W = H = 300; op = 40; L = []
    for i, d in enumerate([0, 8]):
        L.append(layer(i + 1, f"rp{i}", [{"ty": "gr", "it": [
            {"ty": "el", "p": st([0, 0]), "s": kf([(d, [40, 40]), (d + 28, [270, 270])], ease_out=(0.2, 1), ease_in=(0.15, 0.6)), "d": 1},
            {"ty": "st", "c": st(BLUE), "o": kf([(d, 70), (d + 28, 0)]), "w": kf([(d, 8), (d + 28, 1)]), "lc": 2, "lj": 2},
            tr()]}], W, H, op))
    return comp("Ripple", W, H, op, L)

for name, fn in [("burst", burst), ("twinkle", twinkle), ("ripple", ripple)]:
    json.dump(fn(), open(f"{name}.json", "w"), separators=(",", ":"))
    print(name, "ok")
