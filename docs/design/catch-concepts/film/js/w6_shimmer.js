// W6 シマー（Apple Intelligence 風）— the way Apple's own software shows what it found (Photos' Clean Up highlights,
// Visual Look Up's subject glow): no metaphor, just light. After the shot one soft band of light passes diagonally
// over the whole picture; each thing it crosses is revealed — a faint blue glow inside its shape and a soft blue
// outline — in the order the light reaches it. Waiting: the same band passes again, quieter, once per 2.4 s, each
// outline brightening as it goes by; the screen edge glows. Names: one last pass, the glow inside fades, the tags rise.
const W6 = (() => {
  const TH = 62 * Math.PI / 180, UX = Math.cos(TH), UY = Math.sin(TH), BW = 200, SWEEP = .95;   // the band: angle, width, time to cross
  const proj = (x, y) => x * UX + y * UY, S0 = -BW * 1.5, S1 = proj(W, H) + BW * 1.5;
  const bandPos = (t, t0) => lerp(S0, S1, E.inOutSine(seg(t, t0, t0 + SWEEP)));
  const T0 = T_VIS + .02;
  // the sweeps: the first (reveal), one per LOOP while waiting, a last one on the names
  function sweeps() {
    const out = [{ t0: T0, a: 1, kind: 'reveal' }];
    for (let t0 = T0 + SWEEP + .55; t0 < T_NAMES - .4; t0 += LOOP) out.push({ t0, a: .5, kind: 'wait' });
    out.push({ t0: T_NAMES - .08, a: .75, kind: 'names' });
    return out;
  }
  const REV = {};
  function revealT(k) {                                   // when the first band reaches the thing (its nearest point along the band's travel)
    if (REV[k] != null) return REV[k];
    const O = objO(k), s = Math.min(...O.pts.map(p => proj(p[0], p[1])));
    const u = (s - S0) / (S1 - S0), f = Math.acos(1 - 2 * clamp(u)) / Math.PI;   // invert the inOutSine
    return REV[k] = T0 + SWEEP * f;
  }
  const found = k => [revealT(k), revealT(k) + .35];
  const REV_END = () => Math.max(...SCAN_K.map(k => found(k)[1]));
  const TAG = k => scanRank(k) < 0 ? T_NAMES + .1 * k : Math.max(T_NAMES + .1 * k, found(k)[1] + .1);
  const bandAt = (t, s) => { let v = 0; for (const w of sweeps()) { if (t < w.t0 || t > w.t0 + SWEEP + .05) continue; const d = s - bandPos(t, w.t0); v = Math.max(v, w.a * Math.exp(-(d * d) / (2 * (BW / 2.4) ** 2))); } return v; };
  function backdrop(t) {
    photo7(t);
    // inside each found thing: a faint blue glow, and the band's light where it crosses (clipped to the thing's shape)
    SCAN_K.forEach(k => {
      const tr = revealT(k); if (t < tr) return;
      const tag = TAGS[k], M = MK[tag.id], tn = TAG(k), inA = E.outCubic(seg(t, tr, tr + .45)) * (1 - E.inOutCubic(seg(t, tn - .05, tn + .45))); if (inA <= 0) return;
      tmx.save(); tmx.clearRect(M.x - 2, M.y - 2, M.w + 4, M.h + 4); tmx.drawImage(M.c, M.x, M.y); tmx.globalCompositeOperation = 'source-in';
      tmx.fillStyle = `rgba(70,160,255,${.16 * inA})`; tmx.fillRect(M.x, M.y, M.w, M.h);
      sweeps().forEach(w => { if (t < w.t0 || t > w.t0 + SWEEP + .05) return; const c = bandPos(t, w.t0), gx = c * UX, gy = c * UY, g = tmx.createLinearGradient(gx - UX * BW, gy - UY * BW, gx + UX * BW, gy + UY * BW);
        g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(.35, `rgba(200,232,255,${.22 * w.a})`); g.addColorStop(.5, `rgba(240,250,255,${.62 * w.a})`); g.addColorStop(.65, `rgba(200,232,255,${.22 * w.a})`); g.addColorStop(1, 'rgba(255,255,255,0)'); tmx.fillStyle = g; tmx.fillRect(M.x, M.y, M.w, M.h); });
      tmx.restore();
      bgx.save(); photoXform(bgx, t); bgx.globalCompositeOperation = 'screen'; bgx.drawImage(TMP, M.x - 2, M.y - 2, M.w + 4, M.h + 4, M.x - 2, M.y - 2, M.w + 4, M.h + 4); bgx.restore();
    });
  }
  function draw(t) {
    SCAN_K.forEach(k => {
      const tr = revealT(k); if (t < tr - .05) return;
      const O = objO(k), tn = TAG(k), rest = restA(t, tn); if (rest <= 0) return;
      const on = E.outCubic(seg(t, tr - .05, tr + .35));
      queueOutline(O, i => { const p = O.pts[i]; return Math.min(1.2, .55 * on + .65 * bandAt(t, proj(p[0], p[1]))) * rest; }, { width: 14, core: 2.2 });
    });
  }
  function edge(t) { let b = 0; for (const w of sweeps()) b = Math.max(b, w.kind === 'wait' ? .15 * Math.sin(Math.PI * seg(t, w.t0, w.t0 + SWEEP)) : 0); return { boost: b }; }
  function cues() {
    return { kind: 'shimmer', sweep: SWEEP, sweeps: sweeps().map(w => ({ t: +w.t0.toFixed(3), a: w.a, kind: w.kind })),
      reveal: SCAN_K.map(k => ({ id: TAGS[k].id, t: +revealT(k).toFixed(3), x: Math.round(objO(k).cx) })) };
  }
  return { backdrop, draw, edge, TAG, get scanned() { return REV_END() - .1; }, cues };
})();
function conceptW6(t) { CUES.W6 = Object.assign(W6.cues(), { names: T_NAMES, tags: TAGS.map((_, k) => +W6.TAG(k).toFixed(3)), tap: T_TAP, end: T_TAP + .6 }); scan7Frame(t, W6); }
