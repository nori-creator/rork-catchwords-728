"""v3 sound kit for the app (one file per cue, loudness-matched by role) + Core Haptics patterns for the new flow.
Adds the wait sounds (pencil draft, name ink), the landing (riser, pre-impact gap, chord hit, rewards, goal) and the
word-page ink cascade. Output: kit3/wav (48 kHz 24-bit), kit3/caf, kit3/haptics/*.ahap, kit3/index.json.
In the app: no music; sounds follow the system silent switch; haptics alone when silent; never block input.
"""
import os, sys, json, subprocess, wave, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sfxlib import *
import mix3 as M
import pyloudnorm as pyln

OUT = os.path.join(os.path.dirname(__file__), '..', 'kit3')
for d in ('wav', 'caf', 'haptics'): os.makedirs(os.path.join(OUT, d), exist_ok=True)
meter = pyln.Meter(SR, block_size=0.2)
ROLE = {'ui': -26.0, 'wait': -32.0, 'motion': -24.0, 'foley': -22.0, 'earcon': -21.0, 'reward': -19.0}
INDEX = []

def write(name, x, role, note):
    x = np.asarray(x, float)
    if x.ndim == 1: x = stereo(x)
    x = fade(x, 0.001, 0.02)
    pad = np.vstack([x, np.zeros((int(0.25 * SR), 2))])
    try: L = meter.integrated_loudness(pad)
    except Exception: L = -40
    if not np.isfinite(L): L = -40
    x = x * db(ROLE[role] - L); x = x * min(1.0, db(-1.0) / (np.abs(x).max() + 1e-9))
    p = os.path.join(OUT, 'wav', name + '.wav')
    pcm = (np.clip(x, -1, 1) * 8388607).astype('<i4')
    raw = b''.join(int(v).to_bytes(4, 'little', signed=True)[:3] for v in pcm.reshape(-1))
    with wave.open(p, 'wb') as w: w.setnchannels(2); w.setsampwidth(3); w.setframerate(SR); w.writeframes(raw)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', p, '-c:a', 'pcm_s16le', '-f', 'caf', os.path.join(OUT, 'caf', name + '.caf')])
    INDEX.append({'file': name, 'role': role, 'dur_ms': int(len(x) / SR * 1000), 'note': note})

def mixdown(parts, dur):
    out = np.zeros((int(dur * SR), 2))
    for x, t, g in parts:
        if x.ndim == 1: x = stereo(x)
        s = int(t * SR); e = min(len(out), s + len(x)); out[s:e] += x[:e - s] * db(g)
    return out

P = M.PENTA
# --- the analysis (wait) ---
write('wait_bed', M.think_bed(3.0), 'wait', 'AI working: soft bed that opens up; loop the last second, stop (0.15 s fade) on the answer')
write('sketch_outline', M.pencil_tex(.6, seed=10, rate=11, chalk=True), 'wait', 'pencil draws a shape found on device (play per outline, pan to it)')
write('sketch_writing', M.pencil_tex(1.5, seed=30, rate=14, bright=1.2), 'wait', 'pen writing in a draft name pill (very quiet, loop until the name)')
for i in range(4): write(f'shape_found_{i + 1}', glass_drop(NOTE[P[i]]), 'ui', f'shape #{i + 1} closes ({P[i]}): progress climbs the pentatonic')
for i in range(4):
    write(f'name_ink_{i + 1}', mixdown([(tick(NOTE[P[i + 2]], 1), 0, 0), (bell(NOTE[P[i]], 1.0, index=1.3), .01, 1)], 1.0), 'earcon', f'name #{i + 1} inked ({P[i]})')
write('names_resolve', soft_pad([NOTE['D5'], NOTE['F#5'], NOTE['A5']], 1.2, attack=.08), 'earcon', 'all names in (soft D chord)')
# --- choosing ---
write('choose', mixdown([(M.oneshot('ui_tap', .09), 0, 0), (marimba(NOTE['E6'], .3, hardness=.6), .05, -2), (marimba(NOTE['A6'], .4, hardness=.6), .1, -1)], .5), 'ui', 'choose a way to say it (tap + E→A check)')
# --- landing ---
write('dex_open', mixdown([(M.clip('sheet_slide', 0, .36), 0, 0), (whoosh(.4, 500, 1800, 1.1, peak=.5, seed=40), 0, -8)], .45), 'motion', '図鑑 opens')
write('scroll_detent', tick(NOTE['A6'], .8), 'ui', 'a category card passes under the header while scrolling to the slot')
R = load(os.path.join(M.RAW, 'riser_1.mp3')).mean(1); pk = int(np.argmax(np.abs(R)))
write('riser_300', fade(R[pk - int(.3 * SR):pk], .05, .008), 'motion', 'anticipation: ends 70 ms before the hit (leave that gap silent)')
write('riser_500', fade(R[pk - int(.5 * SR):pk], .05, .008), 'motion', 'anticipation, longer variant')
imp = mixdown([(M.chord_hit(['D5', 'F#5', 'A5', 'D6']), 0, 0), (sub_thump(NOTE['D2'], .35), 0, 1), (pitch_shift(M.clip('impact_4', 0, 1.1), .55), 0, -4),
               (whoosh(.35, 4000, 1200, 1.0, peak=.15, seed=42, air=.6), .01, -11), (grains(.6, [NOTE[n] for n in ('A7', 'D8', 'F#7', 'B7')], 45, glen=(.02, .06)), .03, -9)], 1.9)
write('land_impact', imp, 'reward', 'IMPACT: D major chord + weight + tuned ElevenLabs texture + air + sparkle')
write('land_impact_light', imp * .6, 'earcon', 'the same hit for the Instant flow (quicker, lighter)')
write('new_badge', pitch_shift(M.oneshot('bubble_pop', .2), 5), 'ui', 'NEW badge pops')
for i, nm in enumerate(('E6', 'F#6', 'A6')): write(f'count_tick_{i + 1}', tick(NOTE[nm], .9), 'ui', f'rolling counter #{i + 1} ({nm}): category → 枚 → 影, rising')
write('refill', pitch_shift(M.oneshot('bubble_pop', .2), -4), 'ui', 'the next shadow appears')
write('goal_one_more', mixdown([(bell(NOTE['E6'], 1.0, index=1.2), 0, 0), (bell(NOTE['A6'], 1.4, index=1.2), .12, 1)], 1.6), 'earcon', 'goal toast: E→A, the dominant left unresolved (one more word completes the set)')
# --- word page ---
write('draft_pencil', M.pencil_tex(.75, seed=70, rate=12), 'wait', 'the pen drafts a line of the explanation')
for i in range(10): write(f'ink_{i + 1:02d}', marimba(NOTE[P[i]], .45, hardness=.5), 'ui', f'ink cascade line {i + 1} ({P[i]}): play 55 ms apart, a run that climbs two octaves')
write('written_resolve', mixdown([(bell(NOTE['A6'], 1.2, index=1.4), 0, 0), (bell(NOTE['D7'], 1.6, index=1.3), .07, 1)], 1.8), 'reward', 'explanation complete: A→D resolves to the tonic')
json.dump(INDEX, open(os.path.join(OUT, 'index.json'), 'w'), ensure_ascii=False, indent=1)

# ---------- Core Haptics (t = 0 at the named moment) ----------
def tr(t, i, s): return {'Event': {'Time': round(t, 3), 'EventType': 'HapticTransient', 'EventParameters': [{'ParameterID': 'HapticIntensity', 'ParameterValue': i}, {'ParameterID': 'HapticSharpness', 'ParameterValue': s}]}}
def ct(t, d, i, s): return {'Event': {'Time': round(t, 3), 'EventType': 'HapticContinuous', 'EventDuration': d, 'EventParameters': [{'ParameterID': 'HapticIntensity', 'ParameterValue': i}, {'ParameterID': 'HapticSharpness', 'ParameterValue': s}]}}
def curve(t, pid, pts): return {'ParameterCurve': {'ParameterID': pid, 'Time': round(t, 3), 'ParameterCurveControlPoints': [{'Time': a, 'ParameterValue': v} for a, v in pts]}}
CU = M.CU
HAP = {
  # one per found shape and per inked name: light, climbing sharpness (progress you can feel)
  'shape_found': [tr(0, .25, .5)],
  'names_inked': [tr(i * .085, .3 + .05 * i, .6 + .1 * i) for i in range(4)],
  'choose': [tr(0, .55, .8)],
  # landing: t=0 is the impact. anticipation ramp (−0.37 → −0.07), silence, the hit with a short body, rewards
  'land': [ct(-.37, .30, 1, .3), curve(-.37, 'HapticIntensityControl', [(0, .1), (.3, .45)]), curve(-.37, 'HapticSharpnessControl', [(0, .3), (.3, .8)]),
           tr(0, 1.0, .6), ct(0, .15, .5, .2), curve(0, 'HapticIntensityControl', [(0, 1), (.15, 0)]),
           tr(.1, .55, .95), tr(.3, .35, .8), tr(.42, .3, .8), tr(.5, .3, .85), tr(.85, .3, .5), tr(.97, .3, .5)],
  'land_light': [ct(-.25, .18, 1, .4), curve(-.25, 'HapticIntensityControl', [(0, .1), (.18, .35)]), tr(0, .75, .6), tr(.06, .45, .95), tr(.18, .3, .8)],
  'scroll_detent': [tr(0, .25, .9)],
  # B: the full peel (1.1 s rising adhesive drag), the snap free, the flip
  'peel_full': [ct(0, 1.1, 1, .7), curve(0, 'HapticIntensityControl', [(0, .2), (.55, .55), (1.1, .75)]), tr(1.1, .85, .9), tr(1.5, .4, .7)],
  # word page: the ink cascade (three light taps in the run) and the success at the end
  'written': [tr(0, .3, .8), tr(.22, .3, .85), tr(.5, .35, .9), tr(.58, .9, .5), tr(.65, .6, .8)],
}
def shift(pat, d):   # AHAP times must be >= 0: start the pattern d seconds before the impact
    out = []
    for e in pat:
        e = json.loads(json.dumps(e)); (e.get('Event') or e.get('ParameterCurve'))['Time'] = round((e.get('Event') or e.get('ParameterCurve'))['Time'] + d, 3); out.append(e)
    return out
HAP['land'] = shift(HAP['land'], .37); HAP['land_light'] = shift(HAP['land_light'], .25)
NOTE_T0 = {'land': 'start 0.37 s before the impact', 'land_light': 'start 0.25 s before the impact'}
for k, pat in HAP.items():
    json.dump({'Version': 1.0, 'Metadata': {'Project': 'CatchWords', 'Created': '2026-10-10', 'Description': f'{k} (v3; ' + NOTE_T0.get(k, 't=0 is the named moment') + ')'}, 'Pattern': pat},
              open(os.path.join(OUT, 'haptics', k + '.ahap'), 'w'), indent=1)
print(len(INDEX), 'sounds;', len(HAP), 'haptic patterns')
