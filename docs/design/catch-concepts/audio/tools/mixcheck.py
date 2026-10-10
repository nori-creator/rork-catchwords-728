import sys, json, numpy as np, wave
from scipy import signal
from PIL import Image, ImageDraw
SR = 48000
def rd(p):
    w = wave.open(p); x = np.frombuffer(w.readframes(w.getnframes()), '<i2').reshape(-1, 2) / 32768; return x
rows = []
for c in sys.argv[1:]:
    x = rd(f'mixes/{c}.wav'); m = x.mean(1); cues = json.load(open(f'mixes/{c}_cues.json'))
    f, t, S = signal.spectrogram(m, SR, nperseg=1024, noverlap=896)
    S = 10 * np.log10(S + 1e-12); S = np.clip((S - S.max() + 75) / 75, 0, 1); S = S[f < 12000][::-1]
    W, H = 1400, 260; img = Image.fromarray((np.dstack([np.clip(1.5 * S, 0, 1), np.clip(1.5 * S - .5, 0, 1), np.clip(.5 + S - 1.3 * np.maximum(S - .6, 0), 0, 1) * (S > .03)]) * 255).astype(np.uint8)).resize((W, H))
    canvas = Image.new('RGB', (W, H + 120), 'white'); canvas.paste(img, (0, 100)); d = ImageDraw.Draw(canvas)
    dur = len(m) / SR
    # loudness strip (momentary, 100ms)
    n = int(.1 * SR); L = [20 * np.log10(np.sqrt((m[i:i + n] ** 2).mean()) + 1e-9) for i in range(0, len(m) - n, n // 2)]
    for i, v in enumerate(L):
        xx = int(i * (n // 2) / SR / dur * W); hh = int(max(0, v + 50) * 1.6); d.line([(xx, 98), (xx, 98 - hh)], fill=(60, 140, 255), width=3)
    for e in cues:
        xx = int(e['t'] / dur * W); d.line([(xx, 100), (xx, H + 100)], fill=(255, 255, 255), width=1)
    d.text((6, 4), f'{c}  ({dur:.1f}s)  blue = level per 50ms, white lines = cue frames', fill=(0, 0, 0))
    rows.append(canvas)
out = Image.new('RGB', (1400, sum(r.height + 8 for r in rows)), 'white'); y = 0
for r in rows: out.paste(r, (0, y)); y += r.height + 8
out.save('mixcheck.png')
