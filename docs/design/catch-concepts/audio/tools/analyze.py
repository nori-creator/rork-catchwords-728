"""Objective checks for generated sounds (I cannot listen): trimmed length, attack, peak/RMS, centroid,
dominant pitch, plus a spectrogram sheet to look at."""
import sys, os, subprocess, json, numpy as np
from scipy import signal
from PIL import Image, ImageDraw, ImageFont
SR = 48000
def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()
def stats(x):
    m = x.mean(1); a = np.abs(m)
    env = np.convolve(a, np.ones(240) / 240, 'same')
    thr = env.max() * 0.03
    idx = np.where(env > thr)[0]; s, e = (idx[0], idx[-1]) if len(idx) else (0, len(m))
    pk = int(np.argmax(env))
    f, P = signal.welch(m[s:e + 1], SR, nperseg=4096)
    cen = float((f * P).sum() / P.sum())
    # dominant pitch (strongest peak 100–5000 Hz)
    band = (f > 100) & (f < 5000); fd = float(f[band][np.argmax(P[band])])
    tonal = float(P[band].max() / (P[band].mean() + 1e-12))
    return dict(dur=round(len(m) / SR, 3), start=round(s / SR, 3), end=round(e / SR, 3), attack_ms=round((pk - s) / SR * 1000, 1),
                peak_db=round(20 * np.log10(np.abs(x).max() + 1e-9), 1), rms_db=round(20 * np.log10(np.sqrt((m[s:e + 1] ** 2).mean()) + 1e-9), 1),
                centroid=int(cen), f0=int(fd), tonal=round(tonal, 1))
def spec_img(x, title, w=420, h=200):
    m = x.mean(1)
    f, t, S = signal.spectrogram(m, SR, nperseg=1024, noverlap=768)
    S = 10 * np.log10(S + 1e-12); S = np.clip((S - S.max() + 80) / 80, 0, 1)
    keep = f < 16000; S = S[keep][::-1]
    im = Image.fromarray((plt_cmap(S) * 255).astype(np.uint8)).resize((w, h))
    # waveform strip
    wf = Image.new("RGB", (w, 50), (20, 20, 28)); d = ImageDraw.Draw(wf)
    n = len(m); step = max(1, n // w)
    for i in range(w):
        seg = m[i * step:(i + 1) * step]
        if len(seg): v = np.abs(seg).max(); d.line([(i, 25 - v * 24), (i, 25 + v * 24)], fill=(120, 200, 255))
    out = Image.new("RGB", (w, h + 50 + 22), (255, 255, 255)); out.paste(wf, (0, 22)); out.paste(im, (0, 72))
    ImageDraw.Draw(out).text((4, 4), title, fill=(0, 0, 0)); return out
def plt_cmap(v):  # simple magma-ish map
    r = np.clip(1.6 * v, 0, 1); g = np.clip(1.6 * v - .55, 0, 1); b = np.clip(.4 + 1.2 * v - 1.6 * np.maximum(v - .6, 0), 0, 1) * (v > .02)
    return np.dstack([r, g, b])
if __name__ == "__main__":
    files = sys.argv[2:]; out = sys.argv[1]; tiles = []; res = {}
    for p in files:
        x = load(p); st = stats(x); res[os.path.basename(p)] = st
        tiles.append(spec_img(x, f"{os.path.basename(p)}  {st['dur']}s  pk{st['peak_db']}  c{st['centroid']}  f0 {st['f0']}"))
        print(os.path.basename(p), st)
    cols = 3; rows = (len(tiles) + cols - 1) // cols; W, H = tiles[0].size
    sheet = Image.new("RGB", (cols * (W + 6), rows * (H + 6)), (255, 255, 255))
    for i, t in enumerate(tiles): sheet.paste(t, ((i % cols) * (W + 6), (i // cols) * (H + 6)))
    sheet.save(out)
