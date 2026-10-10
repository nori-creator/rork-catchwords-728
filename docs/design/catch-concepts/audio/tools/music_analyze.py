"""Key (Krumhansl-Schmuckler on a chroma profile), tempo (onset autocorrelation), loudness, onset times."""
import sys, numpy as np, subprocess
from scipy import signal
import pyloudnorm as pyln
SR = 48000
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
MAJ = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MIN = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])
def load(p):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
def analyze(p):
    x = load(p); m = x.mean(1)
    f, t, Z = signal.stft(m, SR, nperseg=8192, noverlap=6144); S = np.abs(Z)
    chroma = np.zeros(12); fine = np.zeros(1200)
    for i, fr in enumerate(f):
        if 60 < fr < 4000:
            midi = 69 + 12 * np.log2(fr / 440); e = S[i].sum()
            chroma[int(round(midi)) % 12] += e
            fine[int(round(midi * 100)) % 1200] += e
    best = max([(np.corrcoef(np.roll(MAJ, k), chroma)[0, 1], NAMES[k] + ' major') for k in range(12)] +
               [(np.corrcoef(np.roll(MIN, k), chroma)[0, 1], NAMES[k] + ' minor') for k in range(12)])
    # tuning offset in cents (where energy peaks relative to the semitone grid)
    folded = fine.reshape(12, 100).sum(0); off = int(np.argmax(np.convolve(np.r_[folded[-10:], folded, folded[:10]], np.ones(9), 'same')[10:-10]))
    off = off if off < 50 else off - 100
    # onset envelope + tempo
    f2, t2, Z2 = signal.stft(m, SR, nperseg=1024, noverlap=512); S2 = np.log1p(np.abs(Z2))
    flux = np.maximum(np.diff(S2, axis=1), 0).sum(0); flux = (flux - flux.mean()) / (flux.std() + 1e-9)
    hop = 512 / SR; ac = np.correlate(flux, flux, 'full')[len(flux) - 1:]
    lags = np.arange(len(ac)) * hop; ok = (lags > 60 / 160) & (lags < 60 / 60)
    bpm = 60 / lags[ok][np.argmax(ac[ok])]
    peaks, _ = signal.find_peaks(flux, height=1.5, distance=int(.1 / hop))
    lufs = pyln.Meter(SR).integrated_loudness(x)
    env = np.convolve(np.abs(m), np.ones(4800) / 4800, 'same'); tail = env[-SR:].mean() / env.max()
    return dict(key=best[1], keyconf=round(best[0], 2), tune_cents=off, bpm=round(bpm, 1), lufs=round(lufs, 1), dur=round(len(m) / SR, 2),
                onsets=[round(float(t2[i]), 2) for i in peaks][:14], end_level=round(float(tail), 2))
for p in sys.argv[1:]:
    print(p.split('/')[-1], analyze(p))
