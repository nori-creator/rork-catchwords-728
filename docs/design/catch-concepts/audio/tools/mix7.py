"""Film mixes v7 — the scan phase, redone from scratch (owner 2026-10-10: the picture and the sound from the shot to the
tags were not good). Times come from the films (audio/cues7.json, exported by cues7.js); W2–W5 at the median AI wait,
W2s–W5s at the 90th percentile.

What every proposal shares (the same three phases as the picture):
  shot     the shutter (as before)
  AI on    the screen edge lights: a soft chord blooms (D5 A5 D6) and settles into a quiet bed
  found    each thing's outline appears — the proposal's own voice, one note per thing, climbing (a melody, not beeps)
  waiting  a calm loop on a 100 BPM grid (one bar = 2.4 s = the picture's loop), in the proposal's own instrument,
           soft and low in the mix, long enough for any wait; nothing sustained that wobbles, nothing hissy
  names    the loop stops, a soft chord resolves as the edge light flares, one note per tag (climbing)
The proposal's instrument:
  W2 光のペン   kalimba (modal tines): four notes per thing as the pen draws it, a broken chord while it patrols
  W3 ピント     focus in sound: five detuned voices close into one clear note as each thing comes into focus; the
                three notes build the D major chord, which then breathes while the camera checks focus
  W4 光の流れ   soft blips that run with the light from the screen edge to the thing (panned along), a glass touch
  W6 シマー     Apple-like restraint: one glass touch per thing as the light reaches it, a faint sparkle with each pass
  (W5 投げ縄 was withdrawn by the owner: too quirky; its mix function stays for the record)
Master: glue compression -> -16 LUFS -> limiter -1 dBTP.   usage: python3 mix7.py W2|W3|W4|W5|W2s|… out.wav
"""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sfxlib import *
import pyloudnorm as pyln
from scipy import signal

HERE = os.path.dirname(__file__)
RAW = os.path.join(HERE, '..', 'raw')
ALL = json.load(open(os.path.join(HERE, '..', 'cues7.json')))
N = NOTE.copy(); N.update({'A4': 440.0, 'B4': 493.88, 'D4': 293.66, 'F#4': 369.99, 'E4': 329.63, 'E5': 659.26, 'B5': 987.77})

def lerp(a, b, t): return a + (b - a) * t
def pan_of(x): return float(np.clip((x - 540) / 540 * .75, -.75, .75))
def oneshot(name, length=0.12, pre=0.004, thresh=0.3):
    x = load(os.path.join(RAW, name + '.mp3')); m = np.abs(x).max(1)
    on = int(np.argmax(m > thresh * m.max())); a = max(0, on - int(pre * SR))
    return fade(x[a:a + int(length * SR)], 0.001, min(0.03, length / 3))
def clip(name, start=0, end=None): return fade(load(os.path.join(RAW, name + '.mp3'), start, end), 0.002, 0.03)

# ---------------------------------------------------------------- instruments
def kalimba(f, dur=1.3):
    """a tine: strong fundamental, the tine's inharmonic partials (≈5.9×, 11.7×) dying fast, a soft thumb"""
    t = t_axis(dur); y = np.zeros(len(t))
    for r, a, d in [(1.0, 1.0, 2.6), (2.0, .08, 6), (5.93, .2, 16), (11.7, .05, 30)]: y += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d)
    y *= 1 - np.exp(-t / .0015)
    th = butter(np.random.default_rng(int(f)).standard_normal(len(t)), 'low', 900) * np.exp(-t / .004) * .08
    y = butter(y + th, 'low', 7000); return fade(y / (np.abs(y).max() + 1e-9), .0005, .08)
def blip(f, dur=.25):
    t = t_axis(dur); fr = f * (1 + .02 * (1 - np.exp(-t / .03))); ph = 2 * np.pi * np.cumsum(fr) / SR
    y = (np.sin(ph) + .18 * np.sin(2 * ph)) * np.exp(-t / .07) * (1 - np.exp(-t / .002)); return y / (np.abs(y).max() + 1e-9)
def tink(f, dur=.7): return bell(f, dur, index=.5, decay=7).mean(1)
def focus_tone(f, dur=1.8, conv=.42):
    """five voices spread ±30 cents that close into one clear note — the sound of focusing"""
    t = t_axis(dur); y = np.zeros(len(t))
    for i, c in enumerate((-30, -15, 0, 15, 30)):
        cents = c * np.exp(-t / (conv / 3)); fr = f * 2 ** (cents / 1200); ph = 2 * np.pi * np.cumsum(fr) / SR + i * 1.3
        y += np.sin(ph) + .22 * np.sin(2 * ph) + .06 * np.sin(3 * ph)
    env = np.minimum(1, t / .12) * np.exp(-np.maximum(0, t - .5) / 1.1)
    y = butter(y * env, 'low', 4500); return fade(y / (np.abs(y).max() + 1e-9), .001, .25)
def warm_pad(notes, dur, attack=.8, release=.9, breathe=None):
    t = t_axis(dur); y = np.zeros(len(t))
    for nm in notes:
        f = N[nm]
        for h in range(1, 7): y += np.sin(2 * np.pi * f * h * t + h * .7) / (h * h)
    env = np.minimum(1, t / attack) * np.minimum(1, np.maximum(0, dur - t) / release)
    if breathe: env *= .8 + .2 * np.sin(2 * np.pi * t / breathe - np.pi / 2)
    y = butter(y * env, 'low', 2200); return np.stack([y, np.roll(y, 53)], 1) / (np.abs(y).max() + 1e-9)
def ai_on():
    """the screen edge lights: a soft chord that blooms and settles"""
    t = t_axis(1.8); y = np.zeros(len(t))
    for nm, a in (('D5', 1), ('A5', .8), ('D6', .5)):
        f = N[nm]; y += a * (np.sin(2 * np.pi * f * t) + .15 * np.sin(4 * np.pi * f * t))
    env = (1 - np.exp(-t / .16)) * np.exp(-t / .7); y = butter(y * env, 'low', 5000)
    g = grains(1.0, [N['A6'], N['D7'], N['F#7']], 18, glen=(.02, .05), pan_spread=.7) * .35
    out = np.stack([y, np.roll(y, 31)], 1); out[:len(g)] += g; return fade(out / (np.abs(out).max() + 1e-9), .001, .3)
def resolve():
    out = np.zeros((int(1.9 * SR), 2))
    for i, nm in enumerate(('D6', 'F#6', 'A6')): b = bell(N[nm], 1.6, index=1.1) * (1 - .1 * i); s = int(i * .03 * SR); out[s:s + len(b)] += b
    p = warm_pad(['D5', 'A5'], 1.4, attack=.15, release=.9) * .6; out[:len(p)] += p
    return fade(out / (np.abs(out).max() + 1e-9), .001, .2)

class Mix:
    def __init__(self, dur):
        self.n = int(dur * SR); self.bus = {k: np.zeros((self.n, 2)) for k in ('amb', 'loop', 'sfx', 'send')}; self.events = []
    def add(self, bus, x, t, gain=0.0, pan=None, send=0.0, label=None, haptic=None):
        if x.ndim == 1: x = stereo(x, pan or 0)
        elif pan is not None: x = stereo(x.mean(1), pan)
        s = int(round(t * SR)); g = db(gain)
        if s < 0: x = x[-s:]; s = 0
        e = min(self.n, s + len(x))
        if e <= s: return
        self.bus[bus][s:e] += x[:e - s] * g
        if send: self.bus['send'][s:e] += x[:e - s] * g * send
        if label: self.events.append({'t': round(t, 3), 'cue': label, 'bus': bus, 'gain_db': gain, 'haptic': haptic})

def common(mx, cu):
    sh = cu['shared']; T_CAP, T_NAMES = sh['T_CAP'], sh['T_NAMES']
    amb = load(os.path.join(RAW, 'amb_street.mp3')); amb = np.vstack([amb] * int(np.ceil(mx.n / len(amb) + 1)))[:mx.n]
    amb = peak_norm(butter(amb, 'high', 60), -1) * db(-27); lp = butter(amb, 'low', 900, 2)
    tt = np.arange(mx.n) / SR; k = np.clip((tt - T_CAP) / .35, 0, 1)[:, None]; mx.bus['amb'] += amb * (1 - k) + lp * k * db(-5)
    mx.add('sfx', oneshot('ui_tap', .09), sh['T_PRESS'], -20, 0, label='shutter press')
    mx.add('sfx', clip('shutter', 0, .22), T_CAP - .01, -7, 0, send=.15, label='shutter', haptic='transient 0.8/0.6')
    mx.add('sfx', sub_thump(N['D2'], .22, drop=1.2), T_CAP, -20)
    mx.add('sfx', ai_on(), T_CAP + .1, -24, send=.4, label='AI on: the screen edge lights (soft chord blooms)', haptic='continuous 0.15 rising 0.4s (sharpness 0.2)')
    mx.add('sfx', resolve(), T_NAMES - .02, -21, send=.4, label='names arrive: the edge light flares, a chord resolves', haptic='success')
    mx.add('sfx', oneshot('ui_tap', .09), sh['T_TAP'] + .02, -15, 0, label='tap the word', haptic='transient 0.5/0.7')
def loop_notes(mx, t0, t1, pattern, voice, gain, xs=None, label=None, step=.6):
    """the waiting loop: one note per beat (100 BPM), the pattern cycling, softer on the off-beats; stops at t1"""
    i = 0; t = t0
    while t < t1 - .05:
        nm = pattern[i % len(pattern)]; acc = 0 if i % 4 == 0 else (-2 if i % 2 == 0 else -4)
        mx.add('loop', voice(N[nm]), t, gain + acc, pan_of(xs(t)) if xs else 0, send=.35, label=label if i == 0 else None)
        i += 1; t += step

def concept_W2(mx, cu):            # 光のペン — kalimba
    sh = cu['shared']; common(mx, cu)
    runs = [['D5', 'E5', 'F#5', 'A5'], ['E5', 'F#5', 'A5', 'B5'], ['F#5', 'A5', 'B5', 'D6']]
    for nt in cu['notes']: mx.add('sfx', kalimba(N[runs[nt['obj']][nt['step']]]), nt['t'], -21, pan_of(nt['x']), send=.3, label=f"pen draws ({nt['obj'] + 1}/3)" if nt['step'] == 0 else None, haptic='transient 0.25/0.5')
    for r, (tc, x) in enumerate(zip(cu['close'], cu['closeX'])):
        mx.add('sfx', kalimba(N[['D6', 'E6', 'F#6'][r]]), tc, -20, pan_of(x), send=.4, label='outline closes', haptic='transient 0.4/0.6')
        mx.add('sfx', tink(N[['A6', 'B6', 'D7'][r]]), tc + .02, -29, pan_of(x), send=.4)
    pat = ['A4', 'D5', 'F#5', 'D5', 'B4', 'D5', 'E5', 'D5']; px = {p['t']: p['x'] for p in cu['patrol']}
    if cu['patrol']:
        t0 = cu['patrol'][0]['t']; xs = lambda t: min(px.items(), key=lambda kv: abs(kv[0] - t))[1]
        loop_notes(mx, t0, sh['T_NAMES'], pat, lambda f: kalimba(f, 1.0), -29, xs, 'waiting: kalimba broken chord with the patrol light')
        mx.add('loop', warm_pad(['D4', 'A4'], sh['T_NAMES'] - t0 + .6, breathe=sh['LOOP']), t0 - .3, -37, label='waiting: a low pad under it')
    tags(mx, cu, lambda f: kalimba(f), 'kalimba')
def concept_W3(mx, cu):            # ピント — focus in sound
    sh = cu['shared']; common(mx, cu)
    mx.add('sfx', warm_pad(['D3', 'A3'], 1.2, attack=.25, release=.8), cu['defocus'], -28, label='the picture softens')
    for r, (tf, tl, x) in enumerate(zip(cu['focus'], cu['lock'], cu['focusX'])):
        nm = ['D5', 'F#5', 'A5'][r]
        mx.add('sfx', focus_tone(N[nm]), tf, -21, pan_of(x), send=.4, label=f'focus lands ({r + 1}/3): five voices close into one note', haptic='continuous 0.2→0.05 400ms then transient 0.35/0.5')
        mx.add('sfx', tink(N[['D6', 'F#6', 'A6'][r]]), tl, -28, pan_of(x), send=.4)
    if cu['checks']:
        t0 = cu['checks'][0]['t']
        mx.add('loop', warm_pad(['D4', 'F#4', 'A4', 'D5'], sh['T_NAMES'] - t0 + .9, attack=.6, breathe=sh['LOOP']), t0 - .3, -28.5, label='waiting: the D major chord breathes')
        for c in cu['checks']: mx.add('loop', tink(N[['D6', 'F#6', 'A6'][c['obj']]], .5), c['t'], -33, pan_of(c['x']), send=.4, label='focus check' if c is cu['checks'][0] else None)
    tags(mx, cu, lambda f: tink(f, 1.0), 'tink')
def concept_W4(mx, cu):            # 光の流れ — blips running with the light
    sh = cu['shared']; common(mx, cu)
    for r, (tl, tt_, tc, rx, ox) in enumerate(zip(cu['launch'], cu['touch'], cu['close'], cu['rootX'], cu['objX'])):
        for j, nm in enumerate(['A5', 'D6', 'F#6']): mx.add('sfx', blip(N[nm]), tl + j * (tt_ - tl) / 3, -24, pan_of(lerp(rx, ox, j / 2)), send=.3, label=f'a line of light runs in from the edge ({r + 1}/3)' if j == 0 else None)
        mx.add('sfx', tink(N[['A6', 'B6', 'D7'][r]]), tt_, -25, pan_of(ox), send=.4, haptic='transient 0.3/0.6')
        mx.add('sfx', grains(tc - tt_, [N['D7'], N['A7'], N['F#7']], 40, glen=(.006, .016), pan_spread=.2), tt_, -33, pan_of(ox))
        mx.add('sfx', bell(N[['D6', 'E6', 'F#6'][r]], 1.0, index=.9), tc, -26, pan_of(ox), send=.4, label='outline closes')
    for i, p in enumerate(cu['pulses']):
        nm = ['D6', 'A5', 'B5', 'F#5', 'E6'][i % 5]
        mx.add('loop', blip(N[nm]), p['t'], -28, pan_of(p['rootX']), send=.4, label='waiting: a pulse leaves the edge' if i == 0 else None)
        mx.add('loop', blip(N[nm] * 2), p['t'] + .45, -32, pan_of(p['x']), send=.4)
    if cu['pulses']: mx.add('loop', warm_pad(['D4', 'A4'], sh['T_NAMES'] - cu['pulses'][0]['t'] + .8, breathe=sh['LOOP']), cu['pulses'][0]['t'] - .4, -36, label='waiting: a low pad')
    for j, nm in enumerate(['F#6', 'D6', 'A5']): mx.add('sfx', blip(N[nm]), cu['retract'] + .05 + j * .08, -27, label='the lines draw back' if j == 0 else None)
    tags(mx, cu, lambda f: blip(f, .4), 'blip')
def concept_W5(mx, cu):            # 投げ縄 — marimba run + pop
    sh = cu['shared']; common(mx, cu)
    runs = [['D5', 'F#5', 'A5'], ['E5', 'A5', 'B5'], ['F#5', 'A5', 'D6']]
    for r, (ta, ts, x) in enumerate(zip(cu['appear'], cu['snap'], cu['x'])):
        for j, nm in enumerate(runs[r]): mx.add('sfx', marimba(N[nm], .4, hardness=.45), ta + j * (ts - ta) / 3, -24, pan_of(x), label=f'the loop pulls tight ({r + 1}/3)' if j == 0 else None)
        mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 2 + 2 * r), ts, -21, pan_of(x), label='caught (pop)', haptic='transient 0.55/0.5')
        mx.add('sfx', marimba(N[['D6', 'E6', 'F#6'][r]], .6, hardness=.5), ts + .01, -22, pan_of(x), send=.35)
    w0 = cu['wait0']
    loop_notes(mx, w0 + .3, sh['T_NAMES'], ['D5', 'A4', 'F#5', 'A4', 'E5', 'A4', 'D5', 'B4'], lambda f: marimba(f, .5, hardness=.35), -30, None, 'waiting: soft marimba ostinato')
    mx.add('loop', warm_pad(['D4', 'A4'], sh['T_NAMES'] - w0 + .5, breathe=sh['LOOP']), w0, -37, label='waiting: a low pad')
    for rn in cu['runs']: mx.add('loop', tink(N['A6'], .4), rn['t'], -37, pan_of(rn['x']))
    tags(mx, cu, lambda f: marimba(f, .6, hardness=.5), 'marimba', pop=True)
def concept_W6(mx, cu):            # シマー（Apple Intelligence 風）— restrained: a glass touch per thing, a faint sparkle with each pass of light
    sh = cu['shared']; common(mx, cu); sw = cu['sweep']
    for r, rv in enumerate(sorted(cu['reveal'], key=lambda v: v['t'])):
        mx.add('sfx', tink(N[['D6', 'F#6', 'A6'][r]], .8), rv['t'], -25, pan_of(rv['x']), send=.4, label=f"found: {rv['id']} (the light reaches it)", haptic='transient 0.3/0.4')
    for w in cu['sweeps']:
        if w['kind'] == 'names': continue
        notes, gain = (['A6', 'D7', 'F#7', 'A7', 'D8'], -31) if w['kind'] == 'reveal' else (['D7', 'F#7', 'A7'], -35)
        for j, nm in enumerate(notes): mx.add('loop' if w['kind'] == 'wait' else 'sfx', tink(N[nm], .6), w['t'] + sw * (j + .5) / len(notes), gain, pan_of(120 + 840 * (j + .5) / len(notes)), send=.5, label=('the light passes (reveal)' if w['kind'] == 'reveal' else 'waiting: the light passes again') if j == 0 else None)
    waits = [w for w in cu['sweeps'] if w['kind'] == 'wait']
    if waits: mx.add('loop', warm_pad(['D4', 'A4'], sh['T_NAMES'] - waits[0]['t'] + .6, breathe=sh['LOOP']), waits[0]['t'] - .3, -36, label='waiting: a low pad')
    tags(mx, cu, lambda f: tink(f, .9), 'tink')
def tags(mx, cu, voice, name, pop=False):
    ids = [t['id'] for t in cu['shared']['tags']]; tx = {t['id']: t['x'] for t in cu['shared']['tags']}
    for k, tn in enumerate(cu['tags']):
        nm = ['A5', 'B5', 'D6', 'E6'][k]
        mx.add('sfx', voice(N[nm]), tn + .02, -22, pan_of(tx[ids[k]]), send=.35, label=f'tag: {ids[k]} ({name})', haptic='transient 0.35/0.8')
        if pop: mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 5 + k), tn + .03, -28, pan_of(tx[ids[k]]))

def master(mx):
    B = mx.bus; n = mx.n
    wet = reverb(B['send'], 1.3, damp=6000) * db(-6)
    mixd = B['amb'] + B['loop'] + B['sfx'] + wet
    mixd = butter(mixd, 'high', 30)
    e = envelope_follower(mixd, .005, .12); thr = db(-20)
    gr = np.where(e > thr, (thr * (e / thr) ** .5) / np.maximum(e, 1e-9), 1.0); mixd *= gr[:, None]
    meter = pyln.Meter(SR)
    for _ in range(3): lufs = meter.integrated_loudness(mixd); mixd = limiter(mixd * db(-16 - lufs), -1.0)
    return mixd, meter.integrated_loudness(mixd)

if __name__ == '__main__':
    c, out = sys.argv[1], sys.argv[2]
    cu = ALL[c]; mx = Mix(cu['end'])
    globals()['concept_' + c.rstrip('s')](mx, cu)
    y, lufs = master(mx)
    import wave
    pcm = (np.clip(y, -1, 1) * 32767).astype('<i2')
    with wave.open(out, 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    tp = 20 * np.log10(np.abs(signal.resample_poly(y, 4, 1, axis=0)).max() + 1e-12)
    json.dump(sorted(mx.events, key=lambda e: e['t']), open(out.replace('.wav', '_cues.json'), 'w'), ensure_ascii=False, indent=1)
    print(c, f'LUFS {lufs:.1f}  truepeak {tp:.2f} dBTP  dur {len(y) / SR:.2f}s  cues {len(mx.events)}')
