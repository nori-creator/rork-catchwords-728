"""Film mixes v5. Times come from the films themselves (audio/cues5.json, exported by film/cues.js).

  P1–P3  the scan of the photo (on device, independent of the AI): each sound sits on what the device itself is doing
         and is panned to where it happens. Quiet, airy, no music until the words arrive.
           P1 被写体リフト: a soft light-trace shimmer runs with the light round each outline; a breath of air as the thing
              lifts; a glint for the sheen; a bell as the outline closes (pentatonic, climbing per thing).
           P2 深度スキャン: a sonar-like pulse that loses its brightness as it travels into the distance; a fine tick
              texture for the contour lines; a ping as the second pulse finds each thing (in depth order).
           P3 輪郭解析: a soft static crackle that spreads with the edge wave; glassy ticks for the corner features; a
              rising zip and a pop as each outline closes.
  S1–S3  ways to wait for the names (combinable with any scan): dex slots (fill-in), split-flap (one clack per flip,
         louder on the stop), ink particles (granular stream, a sweep as the word forms).
  A, D   from the tap (choose → land in the 図鑑), as v3. E: the word page — the dither: a granular sweep panned left →
         right as each section breaks up, a breath of grain while the AI writes, a sweep + bell as the text forms.
Master: glue compression -> -16 LUFS -> limiter -1 dBTP.   usage (from audio/): python3 tools/mix5.py P1|P2|P3|S1|S2|S3|A|D|E out.wav
"""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sfxlib import *
import pyloudnorm as pyln
from scipy import signal

HERE = os.path.dirname(__file__)
RAW = os.path.join(HERE, '..', 'raw')
CU = json.load(open(os.path.join(HERE, '..', 'cues5.json')))
SH = CU['shared']; T_PRESS, T_CAP, T_NAMES, T_TAP, T_VIS = SH['T_PRESS'], SH['T_CAP'], SH['T_NAMES'], SH['T_TAP'], SH['T_VIS']
DUR, START = SH['dur'], SH['start']
IDS = [t['id'] for t in SH['tags']]; TAGX = {t['id']: t['x'] for t in SH['tags']}
PENTA = ['D6', 'E6', 'F#6', 'A6', 'B6', 'D7', 'E7', 'F#7', 'A7', 'B7']

def pan_of(x): return float(np.clip((x - 540) / 540 * .8, -.8, .8))
def oneshot(name, length=0.12, pre=0.004, thresh=0.3):
    x = load(os.path.join(RAW, name + '.mp3')); m = np.abs(x).max(1)
    on = int(np.argmax(m > thresh * m.max())); a = max(0, on - int(pre * SR))
    return fade(x[a:a + int(length * SR)], 0.001, min(0.03, length / 3))
def clip(name, start=0, end=None): return fade(load(os.path.join(RAW, name + '.mp3'), start, end), 0.002, 0.03)

# ---------------------------------------------------------------- new voices
def light_trace(dur, seed=1, note='A7'):
    """the light running round an outline: an airy band of noise whose centre climbs, and a faint tone that shimmers"""
    n = int(dur * SR); t = t_axis(dur); x = t / dur
    air = whoosh(dur, 1800, 7000, .8, peak=.55, seed=seed, air=.5).mean(1)
    tone = np.sin(2 * np.pi * NOTE[note] * t * (1 + .004 * np.sin(2 * np.pi * 7 * t))) * (np.sin(np.pi * x) ** 2) * .25
    y = air + tone; return fade(y / (np.abs(y).max() + 1e-9), .02, .08)
def depth_pulse(dur, seed=2):
    """a pulse travelling away: a soft thump, then a sweep that loses its brightness with distance (low-pass closing)"""
    n = int(dur * SR); t = t_axis(dur); x = t / dur
    thump = np.sin(2 * np.pi * 92 * t * np.exp(-t * 2)) * np.exp(-t * 9) * .9
    rng = np.random.default_rng(seed); nz = rng.standard_normal(n)
    f, tt, Z = signal.stft(nz, SR, nperseg=1024, noverlap=768); fc = 7000 * (500 / 7000) ** np.clip(tt / dur, 0, 1)
    _, sw = signal.istft(Z * (f[:, None] < fc[None, :]), SR, nperseg=1024, noverlap=768); sw = sw[:n]
    sw = sw / (np.abs(sw).max() + 1e-9) * np.exp(-x * 2.4) * (1 - np.exp(-t / .03)) * .55
    gl = np.sin(2 * np.pi * np.cumsum(1320 * (.5 ** x)) / SR) * np.exp(-x * 3) * .18
    y = thump + sw + gl; return fade(y / (np.abs(y).max() + 1e-9), .002, .1)
def crackle(dur, seed=3, density=900):
    """soft static: sparse high clicks whose density follows a rise and fall, spreading in stereo"""
    rng = np.random.default_rng(seed); n = int(dur * SR); out = np.zeros((n, 2)); x = np.arange(n) / n
    env = np.sin(np.pi * np.clip(x * 1.1, 0, 1)) ** .8
    k = rng.random(n) < density / SR * env
    imp = np.where(k, rng.uniform(-1, 1, n), 0.0); imp = butter(imp, 'high', 3200, 2)
    pan = rng.uniform(-1, 1, n) * (.2 + .7 * x)
    a = (np.clip(pan, -1, 1) + 1) * np.pi / 4; out[:, 0] = imp * np.cos(a); out[:, 1] = imp * np.sin(a)
    return out / (np.abs(out).max() + 1e-9)
def flap_click(seed, hard=False):
    """one split-flap clack: a bright burst + a small wooden thump"""
    rng = np.random.default_rng(seed); L = int(.03 * SR); t = np.arange(L) / SR
    b = butter(rng.standard_normal(L), 'band', [1500 + rng.uniform(-200, 300), 5200], 2) * np.exp(-t / (.004 if not hard else .006))
    th = np.sin(2 * np.pi * rng.uniform(170, 240) * t) * np.exp(-t / .008) * (.5 if not hard else .9)
    rs = np.sin(2 * np.pi * rng.uniform(2900, 3500) * t) * np.exp(-t / .005) * .25
    y = b + th + rs; return y / (np.abs(y).max() + 1e-9)
def zip_up(dur, seed=4):
    w = whoosh(dur, 700, 5200, .7, peak=.8, seed=seed, air=.3).mean(1); t = t_axis(dur)
    tone = np.sin(2 * np.pi * np.cumsum(900 * (3.2 ** (t / dur))) / SR) * (t / dur) ** 2 * .3
    y = w + tone; return fade(y / (np.abs(y).max() + 1e-9), .005, .02)
def grain_sweep(dur, seed=5, up=True):
    """the dither: a dense granular texture sweeping across the stereo field (left → right)"""
    rng = np.random.default_rng(seed); n = int(dur * SR); out = np.zeros((n, 2)); x = np.arange(n) / n
    for i in range(int(dur * 1400)):
        u = rng.random(); st = int(u * (n - 1)); L = int(rng.uniform(.002, .006) * SR); tt = np.arange(L) / SR
        f = rng.uniform(2500, 7500) * (1 + (u if up else -u) * .2)
        g = np.sin(2 * np.pi * f * tt) * np.hanning(L) * rng.uniform(.3, 1)
        p = -.85 + 1.7 * u + rng.uniform(-.15, .15); a = (np.clip(p, -1, 1) + 1) * np.pi / 4
        e = min(n, st + L); out[st:e, 0] += g[:e - st] * np.cos(a); out[st:e, 1] += g[:e - st] * np.sin(a)
    env = np.sin(np.pi * x) ** .6; out *= env[:, None]
    return out / (np.abs(out).max() + 1e-9)
def think_bed(dur, seed=4):
    t = t_axis(dur); out = np.zeros(len(t))
    for f, a in [(NOTE['A6'], .5), (NOTE['D7'], .35), (NOTE['E7'], .25), (NOTE['F#6'], .3)]:
        out += a * np.sin(2 * np.pi * f * t + 2 * np.pi * .3 * np.sin(2 * np.pi * .7 * t)) * (.6 + .4 * np.sin(2 * np.pi * (.5 + .1 * a) * t))
    rng = np.random.default_rng(seed); air = butter(rng.standard_normal(len(t)), 'high', 6000) * .25
    y = (out / 2 + air) * (.4 + .6 * np.clip(t / (dur * .9), 0, 1) ** 1.5)
    return fade(y / (np.abs(y).max() + 1e-9), .4, .15)
def chord_hit(notes, spread=.007, dur=1.8, index=1.6):
    n = int(dur * SR) + int(spread * len(notes) * SR) + 10; out = np.zeros((n, 2))
    for i, nm in enumerate(notes):
        b = bell(NOTE[nm], dur, index=index); s = int(i * spread * SR); out[s:s + len(b)] += b * (1 - i * .08)
    return out / (np.abs(out).max() + 1e-9)

class Mix:
    def __init__(self, dur, off=0.0):
        self.n = int(dur * SR); self.off = off
        self.bus = {k: np.zeros((self.n, 2)) for k in ('amb', 'music', 'sfx', 'send', 'voice')}; self.events = []; self.gaps = []
    def add(self, bus, x, t, gain=0.0, pan=None, send=0.0, label=None, haptic=None):
        t = t - self.off
        if x.ndim == 1: x = stereo(x, pan or 0)
        elif pan is not None: x = stereo(x.mean(1), pan)
        s = int(round(t * SR)); g = db(gain)
        if s < 0: x = x[-s:]; s = 0
        e = min(self.n, s + len(x))
        if e <= s: return
        self.bus[bus][s:e] += x[:e - s] * g
        if send: self.bus['send'][s:e] += x[:e - s] * g * send
        if label: self.events.append({'t': round(t, 3), 'cue': label, 'bus': bus, 'gain_db': gain, 'haptic': haptic})

def ambience(mx, focus_at=None, gone_at=None):
    amb = load(os.path.join(RAW, 'amb_street.mp3')); amb = np.vstack([amb] * int(np.ceil(mx.n / len(amb) + 1)))[:mx.n]
    amb = peak_norm(butter(amb, 'high', 60), -1) * db(-27); lp = butter(amb, 'low', 900, 2)
    tt = np.arange(mx.n) / SR + mx.off
    k = np.clip((tt - (focus_at if focus_at is not None else T_CAP)) / .35, 0, 1)[:, None]
    y = amb * (1 - k) + lp * k * db(-5)
    if gone_at is not None: y *= (1 - np.clip((tt - gone_at) / .55, 0, 1)[:, None]) ** 2
    mx.bus['amb'] += y
def opening(mx):
    ambience(mx)
    mx.add('sfx', oneshot('ui_tap', .09), T_PRESS, -20, 0, label='shutter press')
    mx.add('sfx', clip('shutter', 0, .22), T_CAP - .01, -7, 0, send=.15, label='shutter', haptic='transient 0.8/0.6')
    mx.add('sfx', sub_thump(NOTE['D2'], .22, drop=1.2), T_CAP, -20)
def bed(mx, t0, t1, gain=-35):
    if t1 - t0 > .3: mx.add('sfx', think_bed(t1 - t0), t0, gain, send=.3, label='waiting for the names (soft bed, opens slowly)')
def tags_in(mx, times, label='tag'):
    for k, tn in enumerate(times):
        p = pan_of(TAGX[IDS[k]])
        mx.add('sfx', tick(NOTE[PENTA[k + 2]], 1), tn, -23, p, label=f'{label}: {IDS[k]}', haptic='transient 0.35/0.8')
        mx.add('sfx', bell(NOTE[PENTA[k]], 1.0, index=1.2), tn + .01, -22, p * .7, send=.35)
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.2, attack=.08), max(times) + .08, -29, send=.3, label='all words in (resolve)')
def tap(mx):
    mx.add('sfx', oneshot('ui_tap', .09), T_TAP + .02, -15, 0, label='tap the word', haptic='transient 0.5/0.7')
    mx.add('sfx', tick(NOTE['A6'], 1), T_TAP + .02, -27)

# ---------------------------------------------------------------- scans (P) — independent of the AI
def concept_P1(mx):
    cu = CU['P1']; opening(mx)
    scanned = [(k, s) for k, s in enumerate(cu['scans']) if s < 50]
    for j, (k, s) in enumerate(scanned):
        p = pan_of(TAGX[IDS[k]])
        mx.add('sfx', light_trace(.64, seed=20 + k, note=['A7', 'B7', 'D8'][j]), s, -25, p, send=.4, label=f'light runs round the outline: {IDS[k]}', haptic='continuous 0.12→0.3 600ms (sharpness 0.4)')
        mx.add('sfx', whoosh(.5, 260, 820, 1.0, peak=.45, seed=30 + k), s + .04, -31, p, label='lifts off the photo')
        mx.add('sfx', grains(.45, [NOTE[n] for n in ('A7', 'D8', 'F#7', 'B7')], 26, glen=(.012, .03), pan_spread=.3), s + .34, -33, p, send=.45, label='sheen')
        mx.add('sfx', bell(NOTE[PENTA[2 * j]], 1.1, index=1.0, decay=2.6), s + .6, -27, p, send=.45, label='outline closes', haptic='transient 0.25/0.6')
    bed(mx, max(s for _, s in scanned) + .7, min(cu['tags']))
    tags_in(mx, cu['tags']); tap(mx)
def concept_P2(mx):
    cu = CU['P2']; opening(mx)
    a, b = cu['pulse1']; mx.add('sfx', depth_pulse(b - a + .5), a, -20, 0, send=.3, label='depth pulse: near → far', haptic='continuous 0.5→0.05 1.1s (sharpness 0.3)')
    mx.add('sfx', grains(b - a, [NOTE[n] for n in ('D7', 'A7', 'D8')], 55, rise=False, glen=(.004, .012), pan_spread=.9), a + .15, -34, send=.2, label='contour lines')
    a2, b2 = cu['pulse2']; mx.add('sfx', depth_pulse(b2 - a2 + .3, seed=7), a2, -26, 0, send=.3, label='second pulse finds the things')
    for j, id_ in enumerate(['cup', 'scooter', 'sign']):
        d = SH['depthOf'][id_]; u = np.clip((1.04 - d) / 1.1, 0, 1); e = np.arccos(1 - 2 * u) / np.pi
        tp = a2 + (b2 - a2) * e; mx.add('sfx', bell(NOTE[PENTA[2 * j]], 1.0, index=1.3), tp, -25, pan_of(TAGX[id_]), send=.4, label=f'found: {id_} (depth {d:.2f})', haptic='transient 0.3/0.7')
    bed(mx, b2, min(cu['tags'])); tags_in(mx, cu['tags']); tap(mx)
def concept_P3(mx):
    cu = CU['P3']; opening(mx)
    a, b = cu['wave']; mx.add('sfx', crackle(b - a + .3), a, -27, send=.15, label='edge wave (static, spreading)', haptic='continuous 0.1 noise-like 1s (sharpness 0.9)')
    rng = np.random.default_rng(9)
    for i in range(18): mx.add('sfx', tick(NOTE[['A7', 'D8', 'F#7'][i % 3]], .7), a + .2 + rng.random() * (b - a), -34, rng.uniform(-.6, .6), label='corner features' if i == 0 else None)
    for j, tc in enumerate(cu['close']):
        id_ = ['cup', 'scooter', 'sign'][j]; p = pan_of(TAGX[id_])
        mx.add('sfx', zip_up(.42, seed=40 + j), tc, -27, p, label=f'outline closes: {id_}')
        mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 3 + 2 * j), tc + .42, -27, p, label='lifted out', haptic='transient 0.35/0.7')
    bed(mx, max(cu['close']) + .5, min(cu['tags'])); tags_in(mx, cu['tags']); tap(mx)

# ---------------------------------------------------------------- name waits (S)
def concept_S1(mx):
    cu = CU['S1']; opening(mx)
    for k, tm in enumerate(cu['masks']): mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 2 + k), tm + .12, -27, pan_of(TAGX[IDS[k]]), label=f'slot appears (No.???): {IDS[k]}', haptic='transient 0.25/0.5')
    for k in range(4):
        for r in range(2): mx.add('sfx', grains(.25, [NOTE['B7'], NOTE['D8']], 30, glen=(.01, .02)), cu['masks'][k] + .9 + k * .3 + r * 1.9, -37, pan_of(TAGX[IDS[k]]), label='shine (waiting)' if k == 0 and r == 0 else None)
    for k, tr in enumerate(cu['reveals']):
        p = pan_of(TAGX[IDS[k]])
        mx.add('sfx', marimba(NOTE[PENTA[k]], .5, hardness=.6), tr + .04, -22, p, label=f'slot filled (DexFillIn): {IDS[k]}', haptic='transient 0.6/0.6')
        mx.add('sfx', grains(.4, [NOTE[n] for n in ('A7', 'D8', 'F#7')], 40, glen=(.015, .04)), tr + .06, -28, p, send=.45)
        if IDS[k] != 'plant': mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 5), tr + .45, -26, p, label='NEW')
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.2, attack=.08), max(cu['reveals']) + .5, -29, send=.3, label='all slots filled')
    tap(mx)
def concept_S2(mx):
    cu = CU['S2']; opening(mx)
    for j, (t, i, c, land) in enumerate(cu['flips']):
        p = pan_of(TAGX[IDS[i]]) + (c - .5) * .04
        mx.add('sfx', flap_click(j, bool(land)), t + .036, -21 if land else -33, p, label=('flap stops' if land else None) if j % 1 == 0 and land else None, haptic='transient 0.45/0.9' if land else None)
    for k, td in enumerate(cu['boardDone']):
        p = pan_of(TAGX[IDS[k]]); mx.add('sfx', bell(NOTE[PENTA[k + 2]], .9, index=1.1), td, -25, p, send=.35, label=f'board done: {IDS[k]}', haptic='transient 0.3/0.5')
        if IDS[k] != 'plant': mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 5), td + .12, -27, p)
    tap(mx)
def concept_S3(mx):
    cu = CU['S3']; opening(mx)
    for k, tm in enumerate(cu['masks']):
        p = pan_of(TAGX[IDS[k]]); mx.add('sfx', grains(.6, [NOTE[n] for n in ('D7', 'F#7', 'A7', 'D8')], 70, glen=(.006, .016), pan_spread=.25), tm, -29, p, send=.4, label=f'glitter runs over the thing: {IDS[k]}')
    stream = grains(T_NAMES - cu['masks'][0], [NOTE[n] for n in ('A7', 'B7', 'D8')], 25, rise=False, glen=(.004, .01), pan_spread=.8)
    mx.add('sfx', stream, cu['masks'][0] + .3, -35, label='particles drift into the tags')
    for k, tr in enumerate(cu['reveals']):
        p = pan_of(TAGX[IDS[k]]); mx.add('sfx', grain_sweep(.5, seed=50 + k), tr, -27, p, label=f'the word forms: {IDS[k]}', haptic='transient train ×4 (0.2/0.9)')
        mx.add('sfx', bell(NOTE[PENTA[k + 2]], 1.0, index=1.2), tr + .42, -25, p, send=.35)
    tap(mx)

# ---------------------------------------------------------------- A / D from the tap; E the word page
def voice(mx, t, gain=-3):
    v = load(os.path.join(RAW, 'voice_zhennai_4.mp3')); v = peak_norm(butter(v, 'high', 90), -6)
    mx.add('voice', v, t - 0.04, gain, label='pronunciation 珍奶 (zh-TW, prefetched — no wait)')
def music(mx, name, start, frm, gain, fin=.35, fout=.8, until=None):
    m = load(os.path.join(RAW, name + '.mp3'))[int(frm * SR):]; end = (until or mx.off + mx.n / SR) - start; m = m[:int(max(.1, end) * SR)]
    mx.add('music', fade(m, fin, fout), start, gain, label=f'music {name} from {frm}s')
def choose(mx, P, kind):
    mx.add('sfx', oneshot('ui_tap', .09), P + .01, -14, label=f'choose 珍奶 ({kind})', haptic='transient 0.55/0.8')
    mx.add('sfx', marimba(NOTE['E6'], .3, hardness=.6), P + .06, -24, label='check'); mx.add('sfx', marimba(NOTE['A6'], .4, hardness=.6), P + .11, -23)
def finale(mx, cu):
    I = cu['I']
    mx.add('sfx', clip('sheet_slide', 0, .36), cu['open'], -16, label='図鑑 opens', haptic='transient 0.3/0.3')
    mx.add('sfx', whoosh(.4, 500, 1800, 1.1, peak=.5, seed=40), cu['open'], -24)
    sd = cu['scroll1'] - cu['scroll0']; mx.add('sfx', whoosh(sd + .1, 2600, 900, 1.2, peak=.25, seed=41, air=.4), cu['scroll0'], -27, label='scroll')
    R = load(os.path.join(RAW, 'riser_1.mp3')).mean(1); pk = int(np.argmax(np.abs(R))); L = int(max(.2, I - .07 - cu['anticip']) * SR)
    rs = fade(R[max(0, pk - L):pk], .05, .01); mx.add('sfx', rs, I - .07 - len(rs) / SR, -21, send=.2, label='anticipation riser', haptic='continuous 0.1→0.45')
    mx.gaps.append(I - mx.off)
    mx.add('sfx', chord_hit(['D5', 'F#5', 'A5', 'D6']), I, -15, send=.35, label='IMPACT: D major chord', haptic='transient 1.0/0.6 + continuous 0.5→0 150ms')
    mx.add('sfx', sub_thump(NOTE['D2'], .35), I, -14, label='impact weight')
    mx.add('sfx', pitch_shift(clip('impact_4', 0, 1.1), .55), I - .003, -19, send=.2, label='impact texture')
    mx.add('sfx', whoosh(.35, 4000, 1200, 1.0, peak=.15, seed=42, air=.6), I + .01, -26, label='shockwave air')
    mx.add('sfx', grains(.6, [NOTE[n] for n in ('A7', 'D8', 'F#7', 'B7')], 45, glen=(.02, .06), pan_spread=.9), I + .03, -24, send=.5, label='sparkle')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 5), I + .1, -24, label='NEW badge', haptic='transient 0.55/0.95')
    for k2, nm in enumerate(('D6', 'F#6')): mx.add('sfx', marimba(NOTE[nm], .35, hardness=.5), I + .16 + k2 * .07, -26)
    mx.add('sfx', tick(NOTE['E6'], .9), I + .3, -25, label='category 6→7 / 19'); mx.add('sfx', tick(NOTE['F#6'], .9), I + .42, -26, label='129→130枚'); mx.add('sfx', tick(NOTE['A6'], .9), I + .5, -26, label='影 37→38')
    tg = I + .85; mx.add('sfx', whoosh(.3, 900, 2200, 1, peak=.4, seed=43), tg, -28, label='goal toast')
    mx.add('sfx', bell(NOTE['E6'], 1.0, index=1.2), tg + .05, -22, send=.3, label='goal: E→A (one more to complete)'); mx.add('sfx', bell(NOTE['A6'], 1.4, index=1.2), tg + .17, -21, send=.35)
def concept_A(mx):
    cu = CU['A']; C, P = cu['C'], cu['P']; ambience(mx, focus_at=T_CAP)
    mx.add('sfx', oneshot('ui_tap', .09), T_TAP + .02, -15, label='tap the word', haptic='transient 0.5/0.7')
    mx.add('sfx', butter(clip('rim_sweep', 0, .45), 'high', 1200), C + .02, -21, send=.3, label='rim light round the cup')
    mx.add('sfx', whoosh(.5, 350, 2400, 1.1, peak=.55, seed=4), C + .22, -17, send=.2, label='lift', haptic='continuous 0.3→0.6 300ms')
    mx.add('sfx', motif(['D6', 'F#6', 'A6'], dur=1.1), C + .4, -19, send=.28, label='CATCH motif D–F#–A')
    mx.add('sfx', grains(.3, [NOTE[n] for n in ('A6', 'D7', 'F#7')], 20, glen=(.02, .05)), C + .5, -28, label='ways to say it appear')
    choose(mx, P, 'list'); voice(mx, cu['voice']); finale(mx, cu)
    mx.add('sfx', whoosh(cu['I'] - cu['launch'] + .02, 2600, 700, 1.0, peak=.85, seed=7), cu['launch'], -18, label='flies into its slot')
    music(mx, 'music_A2', P - .1, 0.0, -12, fin=.2)
def concept_D(mx):
    cu = CU['D']; C, P = cu['C'], cu['P']; ambience(mx, focus_at=T_CAP, gone_at=C + .05)
    mx.add('sfx', oneshot('ui_tap', .09), T_TAP + .02, -15, label='tap the word', haptic='transient 0.5/0.7')
    melt = clip('melt_swell', .1, .78); mx.add('sfx', melt, C + .62 - len(melt) / SR, -19, send=.3, label='photo clears into the page')
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.4, attack=.35), C + .35, -27, send=.3, label='float')
    mx.add('sfx', marimba(NOTE['A6'], .4), cu['card'], -24, label='NEW chip')
    for i, nm in enumerate(('D6', 'E6', 'F#6')): mx.add('sfx', marimba(NOTE[nm], .4, hardness=.45), C + .58 + i * .07, -25, label='ways to say it' if not i else None)
    choose(mx, P, 'card'); voice(mx, cu['voice'])
    mx.add('sfx', whoosh(.4, 600, 1800, 1, peak=.4, seed=31), P + .3, -22, label='card folds away')
    finale(mx, cu); mx.add('sfx', whoosh(cu['I'] - cu['launch'] + .02, 2600, 700, 1.0, peak=.85, seed=32), cu['launch'], -18, label='files into its slot')
    music(mx, 'music_D1', C + .4, 0.0, -18, fin=.5)
def concept_E(mx):
    cu = CU['E']
    mx.add('sfx', oneshot('ui_tap', .09), cu['tap'], -15, label='tap the new word', haptic='transient 0.5/0.7')
    mx.add('sfx', whoosh(cu['detail'] - cu['open'] + .1, 500, 1600, 1, peak=.5, seed=60), cu['open'], -24, label='page zooms out of the slot')
    voice(mx, cu['voice'])
    for s, td in enumerate(cu['dis']): mx.add('sfx', grain_sweep(.6, seed=70 + s), td, -27 - s * 1.5, send=.2, label=f'section {s + 1} breaks into particles (L→R)', haptic='transient train ×3 (0.15/0.9)' if s == 0 else None)
    cloud = grains(cu['done'] - cu['dis'][0] - .4, [NOTE[n] for n in ('A7', 'B7', 'D8', 'F#7')], 22, rise=False, glen=(.003, .009), pan_spread=.9)
    mx.add('sfx', cloud, cu['dis'][0] + .5, -35, label='the cloud while the AI writes (a breath of grain)')
    mx.add('sfx', tick(NOTE['E6'], .6), cu['detail'] + 3.6, -31, label='status: almost done')
    for s, tr in enumerate(cu['ref']):
        mx.add('sfx', grain_sweep(.62, seed=80 + s, up=True), tr, -24 - s, send=.25, label=f'section {s + 1}: particles form the text (L→R)', haptic='transient train ×4 (0.25/0.8)')
        mx.add('sfx', marimba(NOTE[PENTA[s * 2 + 2]], .45, hardness=.5), tr + .5, -25, send=.2)
    mx.add('sfx', bell(NOTE['A6'], 1.2, index=1.4), cu['done'] + .72, -17, send=.3, label='written: A→D (resolve)', haptic='success')
    mx.add('sfx', bell(NOTE['D7'], 1.6, index=1.3), cu['done'] + .8, -16, send=.35)
    mx.add('sfx', grains(.4, [NOTE['A7'], NOTE['D8'], NOTE['F#7']], 25, glen=(.03, .08)), cu['finish'], -26, send=.5, label='sparkle')
    music(mx, 'music_D2', cu['detail'], 0.0, -17, fin=.6, fout=.7)

def master(mx):
    B = mx.bus; n = mx.n
    wet = reverb(B['send'], 1.15, damp=6000) * db(-6); vroom = reverb(B['voice'], .35, .008, damp=7000) * db(-20)
    env = envelope_follower(B['voice'], .01, .3); env = env / (env.max() + 1e-9); k = np.clip(env * 1.4, 0, 1)
    duck, sduck = 1 - .75 * k, 1 - .5 * k
    gap = np.ones(n)
    for I in mx.gaps:
        a, b = int((I - .075) * SR), int(I * SR); r = int(.012 * SR)
        if a < 0 or b > n: continue
        gap[a:b] = db(-18); gap[a:a + r] = np.linspace(1, db(-18), r); gap[b - int(.004 * SR):b] = np.linspace(db(-18), 1, int(.004 * SR))
    mixd = (B['amb'] * (1 - .5 * k)[:, None] + B['music'] * duck[:, None] + wet * sduck[:, None] + B['sfx'] * sduck[:, None]) * gap[:, None] + B['voice'] + vroom
    mixd = butter(mixd, 'high', 30)
    e = envelope_follower(mixd, .005, .12); thr = db(-20)
    gr = np.where(e > thr, (thr * (e / thr) ** .5) / np.maximum(e, 1e-9), 1.0); mixd *= gr[:, None]
    meter = pyln.Meter(SR); lufs = meter.integrated_loudness(mixd); mixd *= db(-16 - lufs); mixd = limiter(mixd, -1.0)
    return mixd, meter.integrated_loudness(mixd)

if __name__ == '__main__':
    c, out = sys.argv[1], sys.argv[2]
    mx = Mix(DUR[c], START.get(c, 0) or 0); mx.concept = c
    globals()['concept_' + c](mx)
    y, lufs = master(mx)
    import wave
    pcm = (np.clip(y, -1, 1) * 32767).astype('<i2')
    with wave.open(out, 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    tp = 20 * np.log10(np.abs(signal.resample_poly(y, 4, 1, axis=0)).max() + 1e-12)
    json.dump(sorted(mx.events, key=lambda e: e['t']), open(out.replace('.wav', '_cues.json'), 'w'), ensure_ascii=False, indent=1)
    print(c, f'LUFS {lufs:.1f}  truepeak {tp:.2f} dBTP  dur {len(y) / SR:.2f}s  cues {len(mx.events)}')
