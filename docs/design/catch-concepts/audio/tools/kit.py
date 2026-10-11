"""Export the app-ready sound kit (one file per cue, loudness-matched by role) and Core Haptics (.ahap)
patterns that line up with the films. Output: kit/wav (48 kHz 24-bit), kit/caf (for AVAudioPlayer), kit/haptics.
"""
import os, sys, json, subprocess, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sfxlib import *
import mix as M
import pyloudnorm as pyln

OUT = os.path.join(os.path.dirname(__file__), '..', 'kit')
for d in ('wav', 'caf', 'haptics'): os.makedirs(os.path.join(OUT, d), exist_ok=True)
meter = pyln.Meter(SR, block_size=0.2)
# role -> target short-term loudness (LUFS). Frequent UI sounds sit lowest so they never tire the ear;
# the reward (arrival) is the loudest moment of the flow.
ROLE = {'ui': -26.0, 'motion': -24.0, 'foley': -22.0, 'earcon': -21.0, 'reward': -19.0, 'bed': -30.0}

def write(name, x, role, note):
    x = fade(np.asarray(x, float), 0.001, 0.02)
    pad = np.vstack([x, np.zeros((int(0.25 * SR), 2))])
    try: L = meter.integrated_loudness(pad)
    except Exception: L = -40
    if not np.isfinite(L): L = -40
    x = x * db(ROLE[role] - L)
    x = x * min(1.0, db(-1.0) / (np.abs(x).max() + 1e-9))  # never above -1 dBFS
    p = os.path.join(OUT, 'wav', name + '.wav')
    pcm = (np.clip(x, -1, 1) * 8388607).astype('<i4')
    import wave
    raw = b''.join(int(v).to_bytes(4, 'little', signed=True)[:3] for v in pcm.reshape(-1))
    with wave.open(p, 'wb') as w: w.setnchannels(2); w.setsampwidth(3); w.setframerate(SR); w.writeframes(raw)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', p, '-c:a', 'pcm_s16le', '-f', 'caf', os.path.join(OUT, 'caf', name + '.caf')])
    INDEX.append({'file': name, 'role': role, 'dur_ms': int(len(x) / SR * 1000), 'note': note})

INDEX = []
pentatonic = [('D6', 'found_1'), ('E6', 'found_2'), ('F#6', 'found_3'), ('A6', 'found_4'), ('B6', 'found_5')]
write('shutter', M.clip('shutter', 0, .22) + np.vstack([sub_thump(NOTE['D2'], .22, drop=1.2) * .3, np.zeros((max(0, int(.22 * SR) - int(.22 * SR)), 2))])[:int(.22 * SR)], 'foley', 'capture; the real app keeps the system shutter (required in Japan) — use this only for the freeze accent')
for nm, f in pentatonic: write(f, glass_drop(NOTE[nm]), 'ui', f'object found #{f[-1]} — climbs D pentatonic ({nm}) so progress is audible')
write('tag_tap', M.oneshot('ui_tap', .09) + np.vstack([tick(NOTE['A6']) * .25, np.zeros((int(.09 * SR) - int(.06 * SR), 2))])[:int(.09 * SR)], 'ui', 'tap a word tag')
write('catch_motif', motif(['D6', 'F#6', 'A6'], dur=1.1), 'earcon', 'signature: rising D–F#–A on glass bells (the moment a word is caught)')
write('catch_motif_short', motif(['D6', 'A6'], gap=.045, dur=1.0), 'earcon', 'short signature for the Instant flow')
arr = np.zeros((int(1.8 * SR), 2)); a1 = bell(NOTE['A6'], 1.2, index=1.6); a2 = bell(NOTE['D7'], 1.6, index=1.4); th = sub_thump(NOTE['D2'], .3)
arr[:len(a1)] += a1; s = int(.07 * SR); arr[s:s + len(a2)] += a2 * 1.1; arr[:len(th)] += th * .5
write('arrival', arr, 'reward', 'added to 図鑑: A→D resolves to the tonic, with low weight (harmonics carry it on phone speakers)')
write('badge_tick', tick(NOTE['D7']), 'ui', '図鑑 badge / counter +1')
write('lift', whoosh(.5, 350, 2400, 1.1, peak=.55, seed=4) + np.vstack([sub_thump(55, .45, drop=.7)[:int(.5 * SR)] * .4, np.zeros((max(0, int(.5 * SR) - int(.45 * SR)), 2))]), 'motion', 'A: sticker lifts off the photo')
write('rim_trace', butter(M.clip('rim_sweep', 0, .45), 'high', 1200) * .7 + np.vstack([grains(.42, [NOTE[n] for n in ('D7', 'E7', 'F#7', 'A7', 'B7', 'D8')], 70), np.zeros((int(.45 * SR) - int(.42 * SR), 2))])[:int(.45 * SR)], 'motion', 'A: light runs round the outline')
write('fly_to_dex', whoosh(.44, 3200, 650, 1.0, peak=.45, pan0=0, pan1=M.TAB_PAN, seed=7), 'motion', 'sticker flies to the 図鑑 tab (falls in pitch, pans left)')
write('die_cut', M.clip('die_cut', 0, .52), 'foley', 'B: cut line round the sticker')
write('holo', grains(.62, [NOTE[n] for n in ('D6', 'F#6', 'A6', 'D7', 'F#7', 'A7', 'D8')], 90, rise=True, glen=(.02, .06), gliss=.05), 'earcon', 'B: holographic flash, in-key glissando')
write('peel', M.clip('peel', .1, .78), 'foley', 'B: peeling off the backing')
write('peel_free', M.oneshot('peel_snap', .12), 'foley', 'B: sticker comes free')
write('sheet_up', M.clip('sheet_slide', 0, .36), 'foley', 'B: album sheet slides up')
thup = butter(np.random.default_rng(5).standard_normal(int(.03 * SR)), 'low', 1500) * np.exp(-np.arange(int(.03 * SR)) / SR / .006)
press = np.zeros((int(.1 * SR), 2)); press[:len(thup)] += stereo(thup * .6); sp = M.oneshot('stick_press', .08); press[:len(sp)] += sp * .3
write('stick_press', press, 'foley', 'B: pressed into the album slot')
write('pop', pitch_shift(M.oneshot('bubble_pop', .2), 1.38), 'ui', 'C: in-place pop (tuned to D5)')
melt = pitch_shift(M.clip('melt_swell', .1, .78), 1.0)
write('melt', melt, 'motion', 'D: photo melts into the page (reverse swell, tuned F→F#)')
for i, nm in enumerate(('D5', 'F#5', 'A5', 'D6')): write(f'type_{i + 1}', marimba(NOTE[nm], .5, hardness=.5), 'ui', f'D: character {i + 1} of the word appears ({nm})')
write('confirm', pitch_shift(M.oneshot('ui_tap', .09), -3), 'ui', 'D: 図鑑に追加 button')
cs = M.clip('card_slot', 0, .33); write('card_slot', cs, 'foley', 'D: files into its slot')
write('twinkle', grains(.3, [NOTE['A7'], NOTE['D8'], NOTE['F#7']], 25, glen=(.03, .08)), 'earcon', 'slot sparkle')
amb = M.load(os.path.join(M.RAW, 'amb_street.mp3'))
write('amb_street_loop', butter(amb, 'high', 60), 'bed', 'concept films only: Taipei street ambience (seamless loop)')
json.dump(INDEX, open(os.path.join(OUT, 'index.json'), 'w'), ensure_ascii=False, indent=1)

# ---------- Core Haptics patterns (time 0 = the tap on the word tag) ----------
def tr(t, i, s): return {'Event': {'Time': round(t, 3), 'EventType': 'HapticTransient', 'EventParameters': [{'ParameterID': 'HapticIntensity', 'ParameterValue': i}, {'ParameterID': 'HapticSharpness', 'ParameterValue': s}]}}
def ct(t, d, i, s): return {'Event': {'Time': round(t, 3), 'EventType': 'HapticContinuous', 'EventDuration': d, 'EventParameters': [{'ParameterID': 'HapticIntensity', 'ParameterValue': i}, {'ParameterID': 'HapticSharpness', 'ParameterValue': s}]}}
def curve(t, pts): return {'ParameterCurve': {'ParameterID': 'HapticIntensityControl', 'Time': round(t, 3), 'ParameterCurveControlPoints': [{'Time': a, 'ParameterValue': v} for a, v in pts]}}
t0 = M.T_TAP + .02; C = M.C
motif3 = lambda t: [tr(t, .55, .5), tr(t + .055, .6, .6), tr(t + .11, .65, .7)]
success = lambda t: [tr(t, .9, .5), tr(t + .07, .6, .8)]
P = {
 'capture': [tr(0, .8, .6)] + [tr(t - M.T_CAP, .25, .5) for t in (1.05, 1.18, 1.30, 1.42)],
 'A_lift': [tr(0, .5, .7), ct(C + .26 - t0, .3, 1, .3), curve(C + .26 - t0, [(0, .3), (.3, .6)])] + motif3(C + .58 - t0) + success(C + 2.05 - t0),
 'B_peel': [tr(0, .5, .7), ct(C + .05 - t0, .5, .35, .85), tr(C + .55 - t0, .6, .4)] + motif3(C + .6 - t0) +
           [tr(C + 1.36 - t0, .3, .6), ct(C + 1.38 - t0, .62, 1, .7), curve(C + 1.38 - t0, [(0, .2), (.62, .7)]), tr(C + 2.02 - t0, .8, .9)] + success(C + 2.92 - t0),
 'C_instant': [tr(0, .5, .7), tr(C + .02 - t0, .7, .5), tr(C + .03 - t0, .5, .6), tr(C + .075 - t0, .6, .7), tr(C + .64 - t0, .6, .6), tr(C + .7 - t0, .4, .8)],
 'D_index': [tr(0, .5, .7), tr(C + .45 - t0, .3, .8)] + [tr(C + .55 + i * .05 - t0, .35, .5 + .08 * i) for i in range(4)] + [tr(C + 1.61 - t0, .7, .4)] + success(C + 2.36 - t0),
}
for k, pat in P.items():
    json.dump({'Version': 1.0, 'Metadata': {'Project': 'CatchWords', 'Created': '2026-10-10', 'Description': f'{k}: synced with the concept film (t=0 is the tap)'}, 'Pattern': pat},
              open(os.path.join(OUT, 'haptics', k + '.ahap'), 'w'), indent=1)
print(len(INDEX), 'sounds;', len(P), 'haptic patterns')
