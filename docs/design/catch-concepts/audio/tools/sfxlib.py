"""CatchWords sound palette: synthesized tonal earcons (all in D major, A=440) + DSP helpers for the mix.

Design rules this module follows
- One key for every pitched sound (D major / D pentatonic), so stacked cues never clash and the music bed
  (also D major) absorbs them.
- Short, soft-attack earcons for frequent actions (<200 ms, no hard transients above 4 kHz) to avoid fatigue.
- Rising pitch = progress / success; arrival resolves to the tonic (A -> D, a perfect fourth up).
- Low-frequency weight is carried by harmonics too ("missing fundamental"), so it reads on phone speakers.
"""
import numpy as np, subprocess
from scipy import signal

SR = 48000
NOTE = {'D5': 587.33, 'E5': 659.26, 'F#5': 739.99, 'A5': 880.0, 'B5': 987.77,
        'D6': 1174.66, 'E6': 1318.51, 'F#6': 1479.98, 'A6': 1760.0, 'B6': 1975.53,
        'D7': 2349.32, 'E7': 2637.02, 'F#7': 2959.96, 'A7': 3520.0, 'B7': 3951.07, 'D8': 4698.64,
        'D2': 73.42, 'D3': 146.83, 'A3': 220.0, 'D4': 293.66, 'F#4': 369.99, 'A4': 440.0}

def t_axis(dur): return np.arange(int(dur * SR)) / SR
def db(x): return 10 ** (x / 20)
def stereo(m, pan=0.0):
    """constant-power pan, pan in [-1, 1]"""
    a = (pan + 1) * np.pi / 4
    return np.stack([m * np.cos(a), m * np.sin(a)], 1)
def load(path, start=None, end=None):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True).stdout
    x = np.frombuffer(raw, np.float32).reshape(-1, 2).astype(np.float64)
    if start is not None or end is not None:
        s = int((start or 0) * SR); e = int(end * SR) if end else len(x); x = x[s:e]
    return x
def fade(x, fin=0.003, fout=0.01):
    n = len(x); a = int(fin * SR); b = int(fout * SR)
    g = np.ones(n)
    if a: g[:a] = np.linspace(0, 1, a) ** 2
    if b: g[-b:] = np.linspace(1, 0, b) ** 2
    return x * (g[:, None] if x.ndim == 2 else g)
def peak_norm(x, to_db=-1.0): return x * db(to_db) / (np.abs(x).max() + 1e-12)
def pitch_shift(x, semis):
    """resample-based shift (changes length a little; fine for one-shots)"""
    r = 2 ** (semis / 12); n = int(len(x) / r)
    return signal.resample(x, n, axis=0)
def butter(x, kind, f, order=2):
    sos = signal.butter(order, f, btype=kind, fs=SR, output='sos'); return signal.sosfilt(sos, x, axis=0)

# ---------------- tonal voices ----------------
def bell(f, dur=1.4, amp=1.0, index=2.2, ratio=3.5, decay=3.2, bright=1.0):
    """glass-celesta FM bell; fast but not clicky attack (2 ms), index decays faster than the body"""
    t = t_axis(dur)
    I = index * bright * np.exp(-t * decay * 2.2)
    env = np.exp(-t * decay) * (1 - np.exp(-t / 0.002))
    out = []
    for det in (-1.6, 1.6):  # cents detune per channel = width
        fd = f * 2 ** (det / 1200)
        y = np.sin(2 * np.pi * fd * t + I * np.sin(2 * np.pi * fd * ratio * t))
        y += 0.18 * np.sin(2 * np.pi * 2.0 * fd * t) * np.exp(-t * decay * 1.6)   # octave partial
        y += 0.05 * np.sin(2 * np.pi * 4.07 * fd * t) * np.exp(-t * decay * 3.0)  # glassy inharmonic
        out.append(y * env)
    return amp * np.stack(out, 1) * 0.5

def glass_drop(f, dur=0.32, amp=1.0):
    """discovery blip: a drop of glass — tiny upward glide into the note, quick decay"""
    t = t_axis(dur)
    glide = f * (0.982 + 0.018 * (1 - np.exp(-t / 0.012)))
    ph = 2 * np.pi * np.cumsum(glide) / SR
    env = np.exp(-t * 16) * (1 - np.exp(-t / 0.0015))
    y = np.sin(ph + 0.6 * np.exp(-t * 30) * np.sin(2 * ph)) + 0.22 * np.sin(2 * ph) * np.exp(-t * 24)
    return amp * stereo(y * env * 0.6)

def marimba(f, dur=0.6, amp=1.0, hardness=0.6):
    """modal bar: fundamental + 3.93 + 9.54 partials, felt mallet noise"""
    t = t_axis(dur)
    modes = [(1.0, 1.0, 7.0), (3.932, 0.22 * hardness, 20.0), (9.538, 0.06 * hardness, 45.0)]
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * d) for r, a, d in modes)
    y *= (1 - np.exp(-t / 0.0012))
    n = np.random.default_rng(int(f)).standard_normal(len(t)) * np.exp(-t / 0.0015) * 0.15 * hardness
    n = butter(n, 'low', 3000)
    return amp * stereo((y + n) * 0.55)

def soft_pad(freqs, dur=1.2, amp=1.0, attack=0.25, release=0.6):
    t = t_axis(dur)
    env = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / release)
    y = sum(np.sin(2 * np.pi * f * t + 0.3 * np.sin(2 * np.pi * 0.5 * f * t)) + 0.3 * np.sin(2 * np.pi * 2 * f * t) for f in freqs)
    y = butter(y, 'low', 3500)
    L = y * env; R = np.roll(y, 37) * env
    return amp * np.stack([L, R], 1) * 0.25 / len(freqs)

def sub_thump(f0=73.42, dur=0.35, amp=1.0, drop=1.35):
    """landing weight: pitched sine drop + 2nd/3rd harmonics so small speakers imply the fundamental"""
    t = t_axis(dur)
    f = f0 * (1 + (drop - 1) * np.exp(-t / 0.025))
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t * 11) * (1 - np.exp(-t / 0.002))
    y = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.22 * np.sin(3 * ph)
    y = np.tanh(1.4 * y) / np.tanh(1.4)
    return amp * stereo(y * env * 0.7)

def tick(f=2349.32, amp=1.0):
    """tiny tonal tick (badge / counter), 40 ms"""
    t = t_axis(0.06); env = np.exp(-t * 90) * (1 - np.exp(-t / 0.0008))
    return amp * stereo(np.sin(2 * np.pi * f * t) * env * 0.5)

# ---------------- noise-based motion ----------------
def whoosh(dur, f0, f1, bw_oct=1.0, amp=1.0, peak=0.6, pan0=0.0, pan1=0.0, seed=1, air=0.25):
    """band-limited noise whose centre glides f0->f1 (log); rise/fall envelope peaking at `peak`;
    stereo position moves pan0->pan1 (sound follows the moving object)."""
    rng = np.random.default_rng(seed); n = int(dur * SR)
    noise = rng.standard_normal(n + 4096)
    f, tt, Z = signal.stft(noise, SR, nperseg=2048, noverlap=1792)
    u = np.clip(tt / dur, 0, 1)
    fc = f0 * (f1 / f0) ** u
    lf = np.log2(np.maximum(f, 1))[:, None]; lc = np.log2(fc)[None, :]
    mask = np.exp(-0.5 * ((lf - lc) / (bw_oct / 2)) ** 2) + air * (f[:, None] > 4000) * 0.15
    _, y = signal.istft(Z * mask, SR, nperseg=2048, noverlap=1792); y = y[:n]
    t = t_axis(dur); x = t / dur
    env = np.where(x < peak, (x / peak) ** 1.6, ((1 - x) / (1 - peak)) ** 1.3)
    y = y / (np.abs(y).max() + 1e-9) * env
    pans = pan0 + (pan1 - pan0) * x
    a = (pans + 1) * np.pi / 4
    return amp * np.stack([y * np.cos(a), y * np.sin(a)], 1) * 0.8

def grains(dur, notes, density=40, amp=1.0, rise=True, seed=3, glen=(0.012, 0.035), pan_spread=0.8, gliss=0.03):
    """sparkle cloud of short sine grains on in-key pitches; density ramps up (rise) or down"""
    rng = np.random.default_rng(seed); n = int(dur * SR); out = np.zeros((n, 2))
    count = int(density * dur)
    for i in range(count):
        u = rng.random() ** (0.7 if rise else 1.4)
        st = int(u * (n - 1)); L = int(rng.uniform(*glen) * SR)
        f = notes[min(len(notes) - 1, int(u * len(notes) * rng.uniform(.7, 1.0)))] if rise else notes[rng.integers(len(notes))]
        tt = np.arange(L) / SR; fr = f * (1 + gliss * tt / (L / SR))
        g = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.hanning(L) * rng.uniform(.4, 1)
        p = rng.uniform(-pan_spread, pan_spread); a = (p + 1) * np.pi / 4
        e = min(n, st + L); out[st:e, 0] += g[:e - st] * np.cos(a); out[st:e, 1] += g[:e - st] * np.sin(a)
    return amp * out * 0.35

def motif(start_notes, gap=0.055, amp=1.0, dur=1.6, index=2.0):
    """the CatchWords 'catch' signature: rising triad arpeggio on glass bells"""
    tot = int((gap * (len(start_notes) - 1) + dur) * SR); out = np.zeros((tot, 2))
    for i, nm in enumerate(start_notes):
        b = bell(NOTE[nm], dur=dur, amp=1.0 - 0.08 * i, index=index)
        s = int(i * gap * SR); out[s:s + len(b)] += b
    return amp * out

# ---------------- space ----------------
_IR = {}
def reverb_ir(rt60=1.2, predelay=0.014, seed=9, damp=5500):
    key = (rt60, predelay, damp)
    if key in _IR: return _IR[key]
    rng = np.random.default_rng(seed); n = int(rt60 * 1.3 * SR); t = np.arange(n) / SR
    tau = rt60 / 6.91
    ir = rng.standard_normal((n, 2)) * np.exp(-t / tau)[:, None]
    # darker tail: progressive low-pass by blending a filtered copy
    lp = butter(ir, 'low', damp, 2); k = np.clip(t / (rt60 * 0.5), 0, 1)[:, None]
    ir = ir * (1 - k) + lp * k
    pd = int(predelay * SR); ir = np.vstack([np.zeros((pd, 2)), ir])
    # early reflections
    for d, g in [(0.007, .5), (0.011, .35), (0.017, .28), (0.023, .2)]:
        i = int(d * SR); ir[i, 0] += g; ir[int(i * 1.07), 1] += g
    ir /= np.sqrt((ir ** 2).sum(0)).max()
    _IR[key] = ir; return ir
def reverb(x, rt60=1.2, predelay=0.014, damp=5500):
    ir = reverb_ir(rt60, predelay, damp=damp)
    return np.stack([signal.fftconvolve(x[:, c], ir[:, c])[:len(x)] for c in (0, 1)], 1)

def envelope_follower(x, attack=0.01, release=0.25):
    m = np.abs(x).max(1) if x.ndim == 2 else np.abs(x)
    a = np.exp(-1 / (attack * SR)); r = np.exp(-1 / (release * SR)); out = np.zeros_like(m); v = 0.0
    # vectorised enough for short films
    for i in range(len(m)):
        c = m[i]; v = a * v + (1 - a) * c if c > v else r * v + (1 - r) * c; out[i] = v
    return out

def limiter(x, ceiling_db=-1.0, lookahead=0.005, release=0.08):
    """look-ahead peak limiter; ceiling checked on a 4x oversampled copy (true-peak-ish)"""
    ceil = db(ceiling_db)
    over = signal.resample_poly(x, 4, 1, axis=0)
    pk = np.abs(over).max(1).reshape(-1, 4).max(1)[:len(x)] if len(over) >= 4 * len(x) else np.abs(x).max(1)
    need = np.minimum(1.0, ceil / np.maximum(pk, 1e-9))
    la = int(lookahead * SR)
    from scipy.ndimage import minimum_filter1d
    need = minimum_filter1d(need, size=2 * la + 1)
    g = np.ones_like(need); v = 1.0; r = np.exp(-1 / (release * SR))
    for i in range(len(need)):
        v = need[i] if need[i] < v else r * v + (1 - r) * need[i]; g[i] = v
    return x * g[:, None]
