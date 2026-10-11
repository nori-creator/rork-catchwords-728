"""Film mixes for the four catch concepts. Every cue is placed on the exact frame of the motion it belongs to
(times below are film seconds; C = 2.22 is the frame the catch starts). Buses: ambience, music, sfx (+reverb
send), voice. Music is ducked under the voice; ambience goes 'out of focus' (low-pass) the moment the photo
freezes. Master: glue compression -> -16 LUFS -> look-ahead limiter at -1 dBTP.

usage: python3 mix.py A|B|C|D out.wav
"""
import sys, os, json, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sfxlib import *
import pyloudnorm as pyln

RAW = os.path.join(os.path.dirname(__file__), '..', 'raw')
T_PRESS, T_CAP, T_TAP, C = .62, .72, 2.12, 2.22
DUR = {'A': 5.9, 'B': 6.4, 'C': 4.2, 'D': 5.9}
TAB_PAN = (297 - 540) / 540  # 図鑑 tab sits left of centre

def oneshot(name, length=0.12, pre=0.004, thresh=0.3, search_from=0.0):
    x = load(os.path.join(RAW, name + '.mp3'))
    s0 = int(search_from * SR); m = np.abs(x[s0:]).max(1)
    on = s0 + int(np.argmax(m > thresh * m.max())); a = max(0, on - int(pre * SR))
    return fade(x[a:a + int(length * SR)], 0.001, min(0.03, length / 3))
def clip(name, start=0, end=None): return fade(load(os.path.join(RAW, name + '.mp3'), start, end), 0.002, 0.03)

class Mix:
    def __init__(self, dur):
        self.n = int(dur * SR); self.bus = {k: np.zeros((self.n, 2)) for k in ('amb', 'music', 'sfx', 'send', 'voice')}
        self.events = []  # for the cue sheet / haptics export
    def add(self, bus, x, t, gain=0.0, pan=None, send=0.0, label=None, haptic=None):
        if x.ndim == 1: x = stereo(x, pan or 0)
        elif pan is not None:  # re-pan a stereo source
            m = x.mean(1); x = stereo(m, pan)
        s = int(round(t * SR)); g = db(gain)
        if s < 0: x = x[-s:]; s = 0
        e = min(self.n, s + len(x));
        if e <= s: return
        self.bus[bus][s:e] += x[:e - s] * g
        if send: self.bus['send'][s:e] += x[:e - s] * g * send
        if label: self.events.append({'t': round(t, 3), 'cue': label, 'bus': bus, 'gain_db': gain, 'haptic': haptic})

# ---------------------------------------------------------------- shared opening
def opening(mx, concept):
    # ambience: real street until the shutter, then "focus" (low-pass + down) — subjective POV
    amb = load(os.path.join(RAW, 'amb_street.mp3'))
    amb = np.vstack([amb] * int(np.ceil(mx.n / len(amb) + 1)))[:mx.n]
    amb = peak_norm(butter(amb, 'high', 60), -1) * db(-27)
    lp = butter(amb, 'low', 900, 2)
    k = np.clip((np.arange(mx.n) / SR - T_CAP) / 0.35, 0, 1)[:, None]
    focus = amb * (1 - k) + lp * k * db(-5)
    if concept == 'D':  # the photo melts away: the street fades to silence
        out = np.clip((np.arange(mx.n) / SR - (C + .05)) / 0.55, 0, 1)[:, None]
        focus = focus * (1 - out) ** 2
    mx.bus['amb'] += focus
    mx.add('sfx', oneshot('ui_tap', .09), T_PRESS, -20, 0, label='shutter press (finger)')
    mx.add('sfx', clip('shutter', 0, .22), T_CAP - .01, -7, 0, send=.15, label='shutter', haptic='rigid 0.8/0.6')
    mx.add('sfx', sub_thump(NOTE['D2'], .22, drop=1.2), T_CAP, -20, label='capture weight')
    sh = butter(clip('analyze_shimmer', 0, 1.45), 'high', 2500)
    sh = fade(sh, .25, .5)
    mx.add('sfx', sh, T_CAP + .12, -30, send=.3, label='AI looking — airy shimmer bed')
    # discovery blips climb the pentatonic as each object is found (progress), panned to where the tag appears
    for t, nm, pan in [(1.05, 'D6', 0.0), (1.18, 'E6', .3), (1.30, 'F#6', -.55), (1.42, 'A6', .55)]:
        mx.add('sfx', glass_drop(NOTE[nm]), t, -19, pan, send=.35, label=f'found object ({nm})', haptic='transient 0.25/0.5')
    # tag tap
    mx.add('sfx', oneshot('ui_tap', .09), T_TAP + .02, -15, 0, label='tap word tag', haptic='transient 0.5/0.7')
    mx.add('sfx', tick(NOTE['A6'], 1), T_TAP + .02, -27)

def voice(mx, t, gain=-3):
    v = load(os.path.join(RAW, 'voice_zhenzhu.mp3')); v = peak_norm(butter(v, 'high', 90), -6)
    mx.add('voice', v, t - 0.08, gain, label='pronunciation 珍珠奶茶 (zh-TW)')
def music(mx, name, film_start, music_from, gain, fade_in=.25, fade_out=.6, until=None):
    m = load(os.path.join(RAW, name + '.mp3'))[int(music_from * SR):]
    end = (until or DUR[mx.concept]) - film_start; m = m[:int(end * SR)]
    m = fade(m, fade_in, fade_out); mx.add('music', m, film_start, gain, label=f'music {name} from {music_from}s')
def arrival(mx, t, pan=TAB_PAN, foley=None, big=True):
    mx.add('sfx', bell(NOTE['A6'], 1.2, index=1.6), t, -15, pan * .6, send=.3, label='arrival chime A6', haptic='success: transient 0.9/0.5 + 0.6/0.8 @+70ms')
    mx.add('sfx', bell(NOTE['D7'], 1.6, index=1.4), t + .07, -14, pan * .6, send=.35, label='arrival chime D7 (resolve to tonic)')
    if big: mx.add('sfx', sub_thump(NOTE['D2'], .3), t, -17, label='arrival weight')
    if foley is not None: mx.add('sfx', foley, t, -15, pan)

# ---------------------------------------------------------------- concepts
def concept_A(mx):
    opening(mx, 'A')
    rim = butter(clip('rim_sweep', 0, .45), 'high', 1200)
    mx.add('sfx', rim, C + .02, -21, send=.3, label='rim light trace (glass sweep)')
    mx.add('sfx', grains(.42, [NOTE[n] for n in ('D7', 'E7', 'F#7', 'A7', 'B7', 'D8')], 70, rise=True, pan_spread=.9), C + .03, -22, send=.4, label='trace sparkle')
    mx.add('sfx', whoosh(.5, 350, 2400, 1.1, peak=.55, seed=4), C + .26, -17, send=.2, label='lift (air up)', haptic='continuous 0.3→0.6, 300ms')
    mx.add('sfx', sub_thump(55, .45, drop=.7), C + .3, -24, label='lift body')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 1.38), C + .46, -25, label='sticker seal (pop, D5)')
    mx.add('sfx', motif(['D6', 'F#6', 'A6'], dur=1.1), C + .58, -18.5, send=.28, label='CATCH motif D–F#–A', haptic='3 transients 0.6/0.6, 55ms apart')
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['A5']], .7), C + .58, -26, send=.2)
    voice(mx, C + .8)
    mx.add('sfx', whoosh(.44, 3200, 650, 1.0, peak=.45, pan0=0, pan1=TAB_PAN, seed=7), C + 1.58, -17, send=.15, label='fly to 図鑑 (pitch falls, pans left)')
    arrival(mx, C + 2.05, foley=oneshot('ui_tap', .08))
    mx.add('sfx', tick(NOTE['D7']), C + 2.1, -24, TAB_PAN, label='badge +1')
    music(mx, 'music_A2', .52, 0.0, -10, fade_in=.05)

def concept_B(mx):
    opening(mx, 'B')
    mx.add('sfx', clip('die_cut', 0, .52), C + .05, -13, send=.12, label='die-cut (craft knife foley)', haptic='continuous texture 0.35, 550ms')
    mx.add('sfx', grains(.55, [NOTE[n] for n in ('A7', 'B7', 'D8')], 30, rise=False, glen=(.006, .015), pan_spread=.6), C + .05, -28)
    sw = whoosh(.6, 700, 350, .8, peak=.8, seed=11, air=0); mx.add('sfx', sw, C + .3, -31, send=.6, label='dream blur swell')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 1.38), C + .55, -20, label='sticker forms (vinyl pop)')
    mx.add('sfx', sub_thump(NOTE['D2'], .2, drop=1.2), C + .55, -24)
    mx.add('sfx', motif(['D6', 'F#6', 'A6']), C + .6, -17, send=.28, label='CATCH motif', haptic='3 transients 0.6/0.6')
    holo = grains(.62, [NOTE[n] for n in ('D6', 'F#6', 'A6', 'D7', 'F#7', 'A7', 'D8')], 90, rise=True, glen=(.02, .06), gliss=.05)
    mx.add('sfx', holo, C + .88, -20, send=.45, label='holographic flash (in-key glissando)')
    mx.add('sfx', butter(clip('holo_glint', 0, .7), 'high', 5000), C + .88, -33, send=.3)
    mx.add('sfx', oneshot('ui_tap', .08), C + 1.36, -22, label='finger on corner')
    mx.add('sfx', clip('peel', .1, .78), C + 1.38, -13, send=.1, label='peel (adhesive foley)', haptic='continuous rising 0.2→0.7, 620ms')
    mx.add('sfx', oneshot('peel_snap', .12), C + 2.02, -14, label='sticker comes free', haptic='transient 0.8/0.9')
    mx.add('sfx', whoosh(.3, 600, 1800, 1, peak=.4, seed=12), C + 2.02, -26)
    mx.add('sfx', clip('sheet_slide', 0, .36), C + 2.1, -14, label='album sheet slides up')
    mx.add('sfx', whoosh(.36, 2200, 700, 1, peak=.5, pan0=0, pan1=0, seed=13), C + 2.56, -20, label='sticker flies to slot')
    thup = butter(np.random.default_rng(5).standard_normal(int(.03 * SR)), 'low', 1500) * np.exp(-np.arange(int(.03 * SR)) / SR / .006)
    mx.add('sfx', stereo(thup * .6), C + 2.92, -12, label='press (paper thup)', haptic='success')
    mx.add('sfx', oneshot('stick_press', .08), C + 2.92, -18)
    arrival(mx, C + 2.92, pan=0)
    mx.add('sfx', tick(NOTE['D7']), C + 2.96, -24, label='count 4→5')
    mx.add('sfx', grains(.3, [NOTE['A7'], NOTE['D8'], NOTE['F#7']], 25, glen=(.03, .08)), C + 2.94, -25, send=.5, label='twinkle')
    voice(mx, C + 3.2)
    music(mx, 'music_B1', T_CAP, 2.25, -19, fade_in=.2)

def concept_C(mx):
    opening(mx, 'C')
    mx.add('sfx', pitch_shift(oneshot('bubble_pop', .2), 1.38), C + .02, -14, label='in-place pop (D5)', haptic='transient 0.7/0.5')
    mx.add('sfx', motif(['D6', 'A6'], gap=.045, dur=1.1), C + .03, -17, send=.25, label='short catch motif D–A')
    voice(mx, C + .12)
    mx.add('sfx', whoosh(.4, 2600, 700, 1, peak=.4, pan0=-.1, pan1=TAB_PAN, seed=21), C + .24, -20, label='mini copy flies to 図鑑')
    mx.add('sfx', bell(NOTE['A6'], .9, index=1.2), C + .64, -19, TAB_PAN * .6, send=.25, label='arrival (small) A6→D7', haptic='success (light)')
    mx.add('sfx', bell(NOTE['D7'], 1.2, index=1.1), C + .7, -18, TAB_PAN * .6, send=.3)
    mx.add('sfx', tick(NOTE['D7']), C + .68, -24, TAB_PAN, label='badge +1')
    music(mx, 'music_C1', T_CAP, 2.61, -19, fade_in=.2)

def concept_D(mx):
    opening(mx, 'D')
    melt = pitch_shift(clip('melt_swell', .1, .78), 1.0)  # F6 partial -> F#6, in key
    mx.add('sfx', melt, C + .62 - len(melt) / SR, -19, send=.3, label='photo melts (reverse swell ends on the page)')
    mx.add('sfx', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.4, attack=.35), C + .35, -26, send=.3, label='float (soft D chord)')
    mx.add('sfx', marimba(NOTE['A6'], .4), C + .45, -24, label='NEW chip')
    for i, nm in enumerate(('D5', 'F#5', 'A5', 'D6')):
        mx.add('sfx', marimba(NOTE[nm], .5, hardness=.5), C + .55 + i * .05, -21, send=.15, label=f'type {"珍珠奶茶"[i]} ({nm})' if True else None)
    voice(mx, C + .78)
    mx.add('sfx', pitch_shift(oneshot('ui_tap', .09), -3), C + 1.61, -14, label='press 図鑑に追加', haptic='transient 0.7/0.4')
    mx.add('sfx', whoosh(.55, 500, 2000, 1.2, peak=.5, seed=31), C + 1.72, -20, send=.2, label='to the dex page')
    cs = clip('card_slot', 0, .33); click = np.argmax(np.abs(cs).max(1)) / SR
    mx.add('sfx', cs, C + 2.36 - click, -13, label='files into slot (card sleeve foley)')
    arrival(mx, C + 2.36, pan=0)
    mx.add('sfx', tick(NOTE['D7']), C + 2.43, -24, label='count 4→5')
    mx.add('sfx', grains(.3, [NOTE['A7'], NOTE['D8'], NOTE['F#7']], 25, glen=(.03, .08)), C + 2.38, -25, send=.5, label='twinkle')
    music(mx, 'music_D1', T_CAP, .45, -16, fade_in=.35)

def master(mx):
    B = mx.bus
    # reverbs: hall for sfx sends, short room for voice
    wet = reverb(B['send'], 1.15, damp=6000) * db(-6)
    vroom = reverb(B['voice'], .35, .008, damp=7000) * db(-20)
    # duck music + ambience under the voice (sidechain)
    env = envelope_follower(B['voice'], .01, .3); env = env / (env.max() + 1e-9)
    k = np.clip(env * 1.4, 0, 1)
    duck = 1 - .75 * k                      # music ~ -12 dB under the word
    sduck = 1 - .5 * k                      # sfx ~ -6 dB under the word
    mixd = B['amb'] * (1 - .5 * k)[:, None] + B['music'] * duck[:, None] + (B['sfx'] + wet) * sduck[:, None] + B['voice'] + vroom
    mixd = butter(mixd, 'high', 30)
    # gentle glue compression (2:1 above -20 dBFS)
    e = envelope_follower(mixd, .005, .12); thr = db(-20)
    gr = np.where(e > thr, (thr * (e / thr) ** .5) / np.maximum(e, 1e-9), 1.0); mixd *= gr[:, None]
    meter = pyln.Meter(SR); lufs = meter.integrated_loudness(mixd)
    mixd *= db(-16 - lufs)
    mixd = limiter(mixd, -1.0)
    return mixd, meter.integrated_loudness(mixd)

if __name__ == '__main__':
    c, out = sys.argv[1], sys.argv[2]
    mx = Mix(DUR[c]); mx.concept = c
    {'A': concept_A, 'B': concept_B, 'C': concept_C, 'D': concept_D}[c](mx)
    y, lufs = master(mx)
    import wave
    pcm = (np.clip(y, -1, 1) * 32767).astype('<i2')
    with wave.open(out, 'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
    tp = 20 * np.log10(np.abs(signal.resample_poly(y, 4, 1, axis=0)).max())
    json.dump(sorted(mx.events, key=lambda e: e['t']), open(out.replace('.wav', '_cues.json'), 'w'), ensure_ascii=False, indent=1)
    print(c, f'LUFS {lufs:.1f}  truepeak {tp:.2f} dBTP  dur {len(y) / SR:.2f}s  cues {len(mx.events)}')
