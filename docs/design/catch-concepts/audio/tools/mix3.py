"""Film mixes v3 (A–D catch concepts + E word-page wait). Every cue sits on the frame of the motion it belongs to;
times come from the film itself (audio/cues3.json, exported by cues3.js).

Sound design of the waits (the core of v3):
  * while the AI works: no music. The street goes "out of focus", the pencil is heard drawing what is already known
    (one stroke per outline, panned to where it is), with a pentatonic blip as each shape closes, and a very soft bed
    that slowly opens up (anticipation without tension).
  * the answer: each name is inked with a crisp tick + a bell climbing D–E–F#–A, then the music blooms in.
  * landing in the 図鑑: a riser, ~70 ms of near-silence (the pre-impact gap that makes the hit land), then a D major
    chord with weight, the shockwave air, sparkles; the counters tick upward; the goal toast ends on the dominant
    (E→A), unresolved on purpose: one more word to complete the set.
  * word page: the pencil writes while the card is generated, the music builds underneath, and the ink cascade is a
    ten-note pentatonic run that lands on the tonic with the completion bell.
Master: glue compression -> -16 LUFS -> look-ahead limiter at -1 dBTP.  usage: python3 mix3.py A|B|C|D|E out.wav
"""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sfxlib import *
import pyloudnorm as pyln
from scipy import signal

HERE = os.path.dirname(__file__)
RAW = os.path.join(HERE, '..', 'raw')
CU = json.load(open(os.path.join(HERE, '..', 'cues3.json')))
SH = CU['shared']; T_PRESS, T_CAP, T_NAMES, T_TAP = SH['T_PRESS'], SH['T_CAP'], SH['T_NAMES'], SH['T_TAP']
DUR = CU['DUR']
PENTA = ['D6', 'E6', 'F#6', 'A6', 'B6', 'D7', 'E7', 'F#7', 'A7', 'B7']

def pan_of(x): return float(np.clip((x - 540) / 540 * .8, -.8, .8))
def oneshot(name, length=0.12, pre=0.004, thresh=0.3, search_from=0.0):
    x = load(os.path.join(RAW, name + '.mp3'))
    s0 = int(search_from * SR); m = np.abs(x[s0:]).max(1)
    on = s0 + int(np.argmax(m > thresh * m.max())); a = max(0, on - int(pre * SR))
    return fade(x[a:a + int(length * SR)], 0.001, min(0.03, length / 3))
def clip(name, start=0, end=None): return fade(load(os.path.join(RAW, name + '.mp3'), start, end), 0.002, 0.03)

# ---------------------------------------------------------------- synth additions
def pencil_tex(dur, seed=1, rate=9.0, bright=1.0, chalk=False):
    """pencil (or chalk) on a surface: band-passed grain under a train of short strokes"""
    rng = np.random.default_rng(seed); n = int(dur * SR)
    nz = rng.standard_normal(n)
    lo, hi = (1400, 4800) if not chalk else (900, 3800)
    x = butter(butter(nz, 'high', lo, 2), 'low', hi * bright, 2)
    crack = (rng.random(n) < .0016) * rng.standard_normal(n) * 3; x = x + butter(crack, 'high', 2500)
    env = np.zeros(n); t = 0.0
    while t < dur:
        L = rng.uniform(.05, .14); s = int(t * SR); e = min(n, s + int(L * SR))
        if e > s: env[s:e] += np.sin(np.linspace(0, np.pi, e - s)) ** 1.5 * rng.uniform(.6, 1)
        t += rng.uniform(.6, 1.4) / rate
    y = x * env; y = fade(y, .01, .05)
    return y / (np.abs(y).max() + 1e-9)
def chord_hit(notes, spread=.007, dur=1.8, index=1.6):
    n = int(dur * SR) + int(spread * len(notes) * SR) + 10; out = np.zeros((n, 2))
    for i, nm in enumerate(notes):
        b = bell(NOTE[nm], dur, index=index)
        if b.ndim == 1: b = stereo(b)
        s = int(i * spread * SR); out[s:s + len(b)] += b * (1 - i * .08)
    return out / (np.abs(out).max() + 1e-9)
def think_bed(dur, seed=4):
    """a very soft, high shimmer that slowly opens (filter + level rise) while the AI is working"""
    t = t_axis(dur); out = np.zeros(len(t))
    for f, a in [(NOTE['A6'], .5), (NOTE['D7'], .35), (NOTE['E7'], .25), (NOTE['F#6'], .3)]:
        out += a * np.sin(2 * np.pi * f * t + 2 * np.pi * .3 * np.sin(2 * np.pi * .7 * t)) * (.6 + .4 * np.sin(2 * np.pi * (.5 + .1 * a) * t))
    rng = np.random.default_rng(seed); air = butter(rng.standard_normal(len(t)), 'high', 6000) * .25
    y = (out / 2 + air) * np.clip(t / (dur * .9), 0, 1) ** 1.5 + (out / 2 + air) * .25
    return fade(y / (np.abs(y).max() + 1e-9), .4, .15)

class Mix:
    def __init__(self, dur):
        self.n = int(dur * SR); self.bus = {k: np.zeros((self.n, 2)) for k in ('amb', 'music', 'sfx', 'send', 'voice')}
        self.events = []; self.gaps = []
    def add(self, bus, x, t, gain=0.0, pan=None, send=0.0, label=None, haptic=None):
        if x.ndim == 1: x = stereo(x, pan or 0)
        elif pan is not None: m = x.mean(1); x = stereo(m, pan)
        s = int(round(t * SR)); g = db(gain)
        if s < 0: x = x[-s:]; s = 0
        e = min(self.n, s + len(x))
        if e <= s: return
        self.bus[bus][s:e] += x[:e - s] * g
        if send: self.bus['send'][s:e] += x[:e - s] * g * send
        if label: self.events.append({'t': round(t, 3), 'cue': label, 'bus': bus, 'gain_db': gain, 'haptic': haptic})

def voice(mx, t, gain=-3):
    v = load(os.path.join(RAW, 'voice_zhennai_4.mp3')); v = peak_norm(butter(v, 'high', 90), -6)
    mx.add('voice', v, t - 0.04, gain, label='pronunciation 珍奶 (zh-TW, prefetched — no wait)')
def music(mx, name, start, frm, gain, fin=.35, fout=.8, until=None):
    m = load(os.path.join(RAW, name + '.mp3'))[int(frm * SR):]
    end = (until or DUR[mx.concept]) - start; m = m[:int(end * SR)]
    mx.add('music', fade(m, fin, fout), start, gain, label=f'music {name} from {frm}s')

# ---------------------------------------------------------------- the analysis (shared by A–D)
def opening(mx, c):
    amb = load(os.path.join(RAW, 'amb_street.mp3')); amb = np.vstack([amb] * int(np.ceil(mx.n / len(amb) + 1)))[:mx.n]
    amb = peak_norm(butter(amb, 'high', 60), -1) * db(-27); lp = butter(amb, 'low', 900, 2)
    tt = np.arange(mx.n) / SR; k = np.clip((tt - T_CAP) / .35, 0, 1)[:, None]
    focus = amb * (1 - k) + lp * k * db(-5)
    if c == 'D': focus *= (1 - np.clip((tt - (CU['D']['C'] + .05)) / .55, 0, 1)[:, None]) ** 2
    mx.bus['amb'] += focus
    mx.add('sfx', oneshot('ui_tap', .09), T_PRESS, -20, 0, label='shutter press')
    mx.add('sfx', clip('shutter', 0, .22), T_CAP - .01, -7, 0, send=.15, label='shutter', haptic='transient 0.8/0.6')
    mx.add('sfx', sub_thump(NOTE['D2'], .22, drop=1.2), T_CAP, -20)
    # the AI at work: a soft bed that opens up until the names arrive (stops on the answer — the room "exhales")
    bed = think_bed(T_NAMES - T_CAP - .15); mx.add('sfx', bed, T_CAP + .15, -33, send=.3, label='AI working — bed opens slowly')
    # shapes first: the pencil draws each outline (panned to it); a pentatonic blip when it closes
    for i, o in enumerate(SH['outlines']):
        mx.add('sfx', pencil_tex(o['dur'], seed=10 + i, rate=11, chalk=True), o['t'], -29, pan_of(o['x']), send=.12, label=f'outline sketch: {o["id"]}')
        mx.add('sfx', glass_drop(NOTE[PENTA[i]]), o['t'] + o['dur'] * .95, -22, pan_of(o['x']), send=.35, label=f'shape found {o["id"]} ({PENTA[i]})', haptic='transient 0.25/0.5')
        # the pen writing in the draft name pill (very quiet, until the answer)
        d0 = o['draft'] + .3; mx.add('sfx', pencil_tex(max(.2, T_NAMES - d0), seed=30 + i, rate=14, bright=1.2), d0, -37, pan_of(o['x']))
    # the answer: each name is inked — tick + bell climbing, then a soft chord as the last one lands
    for i, nmv in enumerate(SH['names']):
        mx.add('sfx', tick(NOTE[PENTA[i + 2]], 1), nmv['t'], -22, pan_of(nmv['x']), label=f'name inked: {nmv["id"]}', haptic='transient 0.35/0.8')
        mx.add('sfx', bell(NOTE[PENTA[i]], 1.0, index=1.3), nmv['t'] + .01, -21, pan_of(nmv['x']) * .7, send=.35)
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.2, attack=.08), SH['names'][-1]['t'] + .06, -28, send=.3, label='all names in (resolve)')
    mx.add('sfx', oneshot('ui_tap', .09), T_TAP + .02, -15, 0, label='tap word tag', haptic='transient 0.5/0.7')
    mx.add('sfx', tick(NOTE['A6'], 1), T_TAP + .02, -27)

def choose(mx, P, kind):
    mx.add('sfx', oneshot('ui_tap', .09), P + .01, -14, label=f'choose 珍奶 ({kind})', haptic='transient 0.55/0.8')
    mx.add('sfx', marimba(NOTE['E6'], .3, hardness=.6), P + .06, -24, label='check')
    mx.add('sfx', marimba(NOTE['A6'], .4, hardness=.6), P + .11, -23)

# ---------------------------------------------------------------- the landing (shared)
def finale(mx, cu, compact=False):
    I = cu['I']; g = -3 if compact else 0
    mx.add('sfx', clip('sheet_slide', 0, .36), cu['open'], -16 + g, label='図鑑 opens', haptic='transient 0.3/0.3')
    mx.add('sfx', whoosh(.4, 500, 1800, 1.1, peak=.5, seed=40), cu['open'], -24 + g)
    # the list scrolls: air + a soft detent each time a category card passes under the header
    sd = cu['scroll1'] - cu['scroll0']; mx.add('sfx', whoosh(sd + .1, 2600, 900, 1.2, peak=.25, seed=41, air=.4), cu['scroll0'], -27 + g, label='scroll')
    for j, tk in enumerate(cu.get('ticks', [])):
        mx.add('sfx', tick(NOTE[['A6', 'F#6', 'D6'][min(j, 2)]], .8), tk['t'], -27 + g, label=f'card passes ({tk["cat"]})', haptic='transient 0.25/0.9')
    # anticipation: riser that stops 70 ms before the hit (then near-silence)
    R = load(os.path.join(RAW, 'riser_1.mp3')).mean(1); pk = int(np.argmax(np.abs(R))); L = int(max(.2, I - .07 - cu['anticip']) * SR)
    rs = fade(R[max(0, pk - L):pk], .05, .01); mx.add('sfx', rs, I - .07 - len(rs) / SR, -21 + g, send=.2, label='anticipation riser', haptic='continuous 0.1→0.45 (sharpness 0.3→0.8)')
    ar = grains(max(.2, I - .07 - cu['anticip']), [NOTE[n] for n in ('D6', 'F#6', 'A6', 'D7', 'F#7', 'A7')], 40, rise=True, glen=(.02, .05))
    mx.add('sfx', fade(ar, .05, .01), I - .07 - len(ar) / SR, -26 + g, send=.35)
    mx.gaps.append(I)
    # the hit
    mx.add('sfx', chord_hit(['D5', 'F#5', 'A5', 'D6']), I, -15 + g, send=.35, label='IMPACT: D major chord', haptic='transient 1.0/0.6 + continuous 0.5→0 150ms')
    mx.add('sfx', sub_thump(NOTE['D2'], .35), I, -14 + g * 2, label='impact weight')
    imp = pitch_shift(clip('impact_4', 0, 1.1), .55); mx.add('sfx', imp, I - .003, -19 + g, send=.2, label='impact texture (ElevenLabs, tuned to A7)')
    mx.add('sfx', whoosh(.35, 4000, 1200, 1.0, peak=.15, seed=42, air=.6), I + .01, -26 + g, label='shockwave air')
    mx.add('sfx', grains(.6, [NOTE[n] for n in ('A7', 'D8', 'F#7', 'B7')], 45, glen=(.02, .06), pan_spread=.9), I + .03, -24 + g, send=.5, label='sparkle')
    # rewards
    s = .06 if compact else .1
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 5), I + s, -24 + g, label='NEW badge', haptic='transient 0.55/0.95')
    tl = .1 if compact else .16
    for k2, nm in enumerate(('D6', 'F#6')): mx.add('sfx', marimba(NOTE[nm], .35, hardness=.5), I + tl + k2 * .07, -26 + g, label='name writes in' if not k2 else None)
    tc = .18 if compact else .3
    mx.add('sfx', tick(NOTE['E6'], .9), I + tc, -25 + g, label='category 6→7 / 19', haptic='transient 0.35/0.8')
    mx.add('sfx', grains(.3, [NOTE['B7'], NOTE['D8']], 30, glen=(.01, .03)), I + tc + .25, -31 + g, label='progress glint')
    mx.add('sfx', tick(NOTE['F#6'], .9), I + (.26 if compact else .42), -26 + g, label='129→130枚')
    mx.add('sfx', tick(NOTE['A6'], .9), I + (.32 if compact else .5), -26 + g, label='影 37→38')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), -4), I + (.4 if compact else .7), -30 + g, label='next shadow appears (refill)')
    tg = cu['I'] + (.45 if compact else .85)
    mx.add('sfx', whoosh(.3, 900, 2200, 1, peak=.4, seed=43), tg, -28 + g, label='goal toast')
    mx.add('sfx', bell(NOTE['E6'], 1.0, index=1.2), tg + .05, -22 + g, send=.3, label='goal: E→A (dominant, unresolved: one more to complete)', haptic='transient 0.3/0.5 ×2')
    mx.add('sfx', bell(NOTE['A6'], 1.4, index=1.2), tg + .17, -21 + g, send=.35)

# ---------------------------------------------------------------- concepts
def concept_A(mx):
    cu = CU['A']; C, P = cu['C'], cu['P']; opening(mx, 'A')
    mx.add('sfx', butter(clip('rim_sweep', 0, .45), 'high', 1200), C + .02, -21, send=.3, label='clean outline inks round the cup')
    mx.add('sfx', grains(.34, [NOTE[n] for n in ('D7', 'E7', 'F#7', 'A7', 'B7', 'D8')], 70, rise=True, pan_spread=.9), C + .03, -23, send=.4)
    mx.add('sfx', whoosh(.5, 350, 2400, 1.1, peak=.55, seed=4), C + .22, -17, send=.2, label='lift', haptic='continuous 0.3→0.6 300ms')
    mx.add('sfx', motif(['D6', 'F#6', 'A6'], dur=1.1), C + .4, -19, send=.28, label='CATCH motif D–F#–A', haptic='3 transients 0.6/0.6')
    mx.add('sfx', grains(.3, [NOTE[n] for n in ('A6', 'D7', 'F#7')], 20, glen=(.02, .05)), C + .5, -28, label='ways to say it appear')
    choose(mx, P, 'list'); voice(mx, cu['voice'])
    finale(mx, cu)
    mx.add('sfx', whoosh(cu['I'] - cu['launch'] + .02, 2600, 700, 1.0, peak=.85, seed=7), cu['launch'], -18, label='flies into its slot')
    music(mx, 'music_A2', P - .1, 0.0, -12, fin=.2)

def concept_B(mx):
    cu = CU['B']; C, P = cu['C'], cu['P']; opening(mx, 'B')
    mx.add('sfx', clip('sheet_slide', 0, .36), cu['sheet'], -15, label='sheet up')
    choose(mx, P, 'sheet'); mx.add('sfx', whoosh(.3, 1600, 500, 1, peak=.3, seed=51), P + .18, -26, label='sheet down')
    mx.add('sfx', clip('die_cut', 0, .52), C + .05, -13, send=.12, label='die-cut', haptic='continuous 0.35 550ms')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 1.38), C + .55, -20, label='sticker forms')
    mx.add('sfx', motif(['D6', 'F#6', 'A6']), C + .6, -18, send=.28, label='CATCH motif', haptic='3 transients 0.6/0.6')
    voice(mx, cu['voice'])
    holo = grains(.62, [NOTE[n] for n in ('D6', 'F#6', 'A6', 'D7', 'F#7', 'A7', 'D8')], 90, rise=True, glen=(.02, .06), gliss=.05)
    mx.add('sfx', holo, C + .88, -21, send=.45, label='holographic flash')
    p0, p1, f1 = cu['peel0'], cu['peel1'], cu['flip1']
    mx.add('sfx', oneshot('ui_tap', .08), p0 - .02, -22, label='finger on the corner')
    pe = clip('peel', .1, .86); mx.add('sfx', pe, p0, -13, send=.1, label='peel — all the way', haptic='continuous rising 0.2→0.75 1.1s')
    mx.add('sfx', fade(clip('peel', .3, .86), .08, .05), p0 + .52, -15, send=.1)
    mx.add('sfx', oneshot('peel_snap', .12), p1 - .01, -12, label='comes free', haptic='transient 0.85/0.9')
    mx.add('sfx', whoosh(f1 - p1 + .1, 700, 2600, 1, peak=.5, seed=52), p1, -21, label='turns face-up (card flip)')
    mx.add('sfx', grains(.3, [NOTE[n] for n in ('A6', 'D7', 'F#7', 'A7')], 50, rise=True, glen=(.015, .04)), f1 - .2, -22, send=.4, label='glint over the laminate')
    mx.add('sfx', bell(NOTE['A6'], .8, index=1.1), f1 - .02, -24, send=.3, label='face reveal')
    mx.add('sfx', oneshot('ui_tap', .08), cu['grab'], -22, label='finger picks it up', haptic='transient 0.4/0.6')
    finale(mx, cu)
    mx.add('sfx', whoosh(cu['I'] - cu['grab'] - .1, 1800, 800, 1.0, peak=.8, seed=53), cu['grab'] + .1, -20, label='placed into the slot')
    thup = butter(np.random.default_rng(5).standard_normal(int(.03 * SR)), 'low', 1500) * np.exp(-np.arange(int(.03 * SR)) / SR / .006)
    mx.add('sfx', stereo(thup * .6), cu['I'], -14, label='press (paper thup)')
    music(mx, 'music_B1', T_TAP + .1, 0.0, -21, fin=.4)

def concept_C(mx):
    cu = CU['C']; C, P = cu['C'], cu['P']; opening(mx, 'C')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 3), cu['pop0'], -22, label='popover opens')
    choose(mx, P, 'popover')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 1.38), C + .02, -15, label='in-place pop', haptic='transient 0.7/0.5')
    mx.add('sfx', motif(['D6', 'A6'], gap=.045, dur=1.1), C + .03, -18, send=.25, label='short catch motif')
    voice(mx, cu['voice'])
    finale(mx, cu, compact=True)
    mx.add('sfx', whoosh(cu['I'] - C - .3, 2600, 700, 1, peak=.8, seed=21), C + .3, -20, label='mini copy flies in')
    mx.add('sfx', whoosh(.35, 1500, 400, 1, peak=.3, seed=22), cu['down'], -24, label='sheet drops — camera ready')
    mx.add('sfx', tick(NOTE['D7'], .7), cu['down'] + .35, -28, label='ready for the next word')
    music(mx, 'music_C1', T_NAMES + .05, 0.0, -21, fin=.5)

def concept_D(mx):
    cu = CU['D']; C, P = cu['C'], cu['P']; opening(mx, 'D')
    melt = clip('melt_swell', .1, .78); mx.add('sfx', melt, C + .62 - len(melt) / SR, -19, send=.3, label='photo melts')
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.4, attack=.35), C + .35, -27, send=.3, label='float')
    mx.add('sfx', marimba(NOTE['A6'], .4), cu['card'], -24, label='NEW chip')
    for i, nm in enumerate(('D6', 'E6', 'F#6')): mx.add('sfx', marimba(NOTE[nm], .4, hardness=.45), C + .55 + i * .07, -25, label='ways to say it' if not i else None)
    choose(mx, P, 'card'); voice(mx, cu['voice'])
    mx.add('sfx', whoosh(.4, 600, 1800, 1, peak=.4, seed=31), P + .3, -22, label='card folds into the cup')
    finale(mx, cu)
    mx.add('sfx', whoosh(cu['I'] - cu['launch'] + .02, 2600, 700, 1.0, peak=.85, seed=32), cu['launch'], -18, label='files into its slot')
    music(mx, 'music_D1', T_NAMES + .6, 0.0, -18, fin=.5)

def concept_E(mx):
    cu = CU['E']; lines = cu['lines']
    mx.add('sfx', oneshot('ui_tap', .09), cu['tap'], -15, label='tap the new word', haptic='transient 0.5/0.7')
    mx.add('sfx', whoosh(cu['detail'] - cu['open'] + .1, 500, 1600, 1, peak=.5, seed=60), cu['open'], -24, label='page zooms out of the slot')
    voice(mx, cu['voice'])
    # the pen writes each line's draft, then a softer refining pass
    for i, l in enumerate(lines):
        mx.add('sfx', pencil_tex(.75, seed=70 + i, rate=12), l['draft'], -31, (i % 3 - 1) * .25, label='pencil draft' if i == 0 else None)
        if l['refine'] < cu['done'] - .2: mx.add('sfx', pencil_tex(min(.6, cu['done'] - l['refine']), seed=90 + i, rate=10, bright=.8), l['refine'], -36, (i % 3 - 1) * .2)
    mx.add('sfx', tick(NOTE['E6'], .6), cu['detail'] + 3.6, -31, label='status: almost done')
    # ink cascade: a ten-note pentatonic run that lands on the tonic with the completion bell
    for i, l in enumerate(lines):
        mx.add('sfx', marimba(NOTE[PENTA[i]], .45, hardness=.5), l['ink'], -25 + i * .3, (i % 3 - 1) * .2, send=.2, label='ink cascade (pentatonic run)' if i == 0 else None, haptic='transient 0.3/0.8' if i in (0, 4, 9) else None)
    mx.add('sfx', bell(NOTE['A6'], 1.2, index=1.4), cu['done'] + .58, -17, send=.3, label='written: A→D (resolve)', haptic='success')
    mx.add('sfx', bell(NOTE['D7'], 1.6, index=1.3), cu['done'] + .65, -16, send=.35)
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 5), cu['done'] + .22, -26, label='check')
    mx.add('sfx', grains(.4, [NOTE['A7'], NOTE['D8'], NOTE['F#7']], 25, glen=(.03, .08)), cu['done'] + .7, -26, send=.5, label='sparkle')
    music(mx, 'music_D2', cu['detail'], 0.0, -16, fin=.6, fout=.7)

def master(mx):
    B = mx.bus; n = mx.n
    wet = reverb(B['send'], 1.15, damp=6000) * db(-6)
    vroom = reverb(B['voice'], .35, .008, damp=7000) * db(-20)
    env = envelope_follower(B['voice'], .01, .3); env = env / (env.max() + 1e-9); k = np.clip(env * 1.4, 0, 1)
    duck, sduck = 1 - .75 * k, 1 - .5 * k
    # pre-impact gap: everything but the voice drops ~18 dB for the 70 ms before each hit
    gap = np.ones(n)
    for I in mx.gaps:
        a, b = int((I - .075) * SR), int(I * SR); r = int(.012 * SR)
        gap[a:b] = db(-18); gap[a:a + r] = np.linspace(1, db(-18), r); gap[b - int(.004 * SR):b] = np.linspace(db(-18), 1, int(.004 * SR))
    pre = (B['amb'] * (1 - .5 * k)[:, None] + B['music'] * duck[:, None] + wet * sduck[:, None]) * gap[:, None]
    # the hit itself is not gapped (it starts at I)
    mixd = pre + B['sfx'] * sduck[:, None] * np.where(np.arange(n) / SR < 0, 1, gap)[:, None] + B['voice'] + vroom
    mixd = butter(mixd, 'high', 30)
    e = envelope_follower(mixd, .005, .12); thr = db(-20)
    gr = np.where(e > thr, (thr * (e / thr) ** .5) / np.maximum(e, 1e-9), 1.0); mixd *= gr[:, None]
    meter = pyln.Meter(SR); lufs = meter.integrated_loudness(mixd)
    mixd *= db(-16 - lufs); mixd = limiter(mixd, -1.0)
    return mixd, meter.integrated_loudness(mixd)

if __name__ == '__main__':
    c, out = sys.argv[1], sys.argv[2]
    mx = Mix(DUR[c]); mx.concept = c
    {'A': concept_A, 'B': concept_B, 'C': concept_C, 'D': concept_D, 'E': concept_E}[c](mx)
    y, lufs = master(mx)
    import wave
    pcm = (np.clip(y, -1, 1) * 32767).astype('<i2')
    with wave.open(out, 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    tp = 20 * np.log10(np.abs(signal.resample_poly(y, 4, 1, axis=0)).max())
    json.dump(sorted(mx.events, key=lambda e: e['t']), open(out.replace('.wav', '_cues.json'), 'w'), ensure_ascii=False, indent=1)
    print(c, f'LUFS {lufs:.1f}  truepeak {tp:.2f} dBTP  dur {len(y) / SR:.2f}s  cues {len(mx.events)}')
